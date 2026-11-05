'use strict';
const $=id=>document.getElementById(id), levels=['空いている','やや混雑','満席','不明'], colors=['#278963','#bf790c','#cd5056','#7c8582'], categories=['カフェ','図書館','自習室','コワーキング'], symbols=['☕','本','✎','▣'];
const key='workspot-web-v1';let storageOK=true;
function read(k,fallback){try{return JSON.parse(localStorage.getItem(k))??fallback}catch{storageOK=false;return fallback}}
let profiles=read(key+'-profiles',{}),visits=read(key+'-visits',[]);if(!profiles||typeof profiles!=='object'||Array.isArray(profiles))profiles={};if(!Array.isArray(visits))visits=[];
const spots=Array.from({length:50},(_,i)=>({id:String(i+1),name:i===0?'PR・サンプルカフェ':`サンプル・${categories[i%4]}${String(i+1).padStart(2,'0')}`,category:categories[i%4],lat:35.695+(((i*17+13)%101)/100-.5)*.054,lon:139.705+(((i*43+27)%103)/102-.5)*.054,level:i===0?0:(i*7+1)%4,sponsored:i===0,price:i%4===1?0:[400,700,1000,1500,2500][Math.floor(i/4)%5]}));
let signals=read(key+'-signals',{});if(!signals||typeof signals!=='object'||Array.isArray(signals))signals={};
let allowEstimateLocation=false,creatingFacility=false,detailID=null,addressVersion=0,verifiedAddress='';
function validCoordinates(p){return Number.isFinite(p.lat)&&Math.abs(p.lat)<=85&&Number.isFinite(p.lon)&&Math.abs(p.lon)<=180}
for(const [id,p] of Object.entries(profiles)){if(id.startsWith('local-')&&p?.custom&&validCoordinates(p)&&typeof p.name==='string')spots.push({id,name:p.name,category:categories.includes(p.category)?p.category:'カフェ',lat:p.lat,lon:p.lon,price:0,level:3,sponsored:false,custom:true})}
function evidence(id){return CrowdEstimate.estimate(signals[id]||{},visits,id,allowEstimateLocation&&enabled&&!document.hidden)}
function data(s){const p=profiles[s.id]||{},estimate=evidence(s.id);const hasManual=Number.isInteger(p.level)&&p.level>=0&&p.level<4;
 const manualFresh=hasManual&&(!p.levelAt||CrowdEstimate.recent(p.levelAt,Date.now(),3600000));
 const level=manualFresh&&p.level!==3?p.level:estimate.level!==3?estimate.level:(s.custom||hasManual)?3:s.level;
 return {...s,name:typeof p.name==='string'&&p.name.trim()?p.name:s.name,address:typeof p.address==='string'?p.address:'',
 ...(validCoordinates(p)?{lat:p.lat,lon:p.lon}:{}),category:categories.includes(p.category)?p.category:s.category,price:Number.isFinite(p.price)&&p.price>=0?p.price:s.price,
 menu:typeof p.menu==='string'?p.menu:'',hours:typeof p.hours==='string'?p.hours:'',memo:typeof p.memo==='string'?p.memo:'',level,
 source:manualFresh&&p.level!==3?'施設側の更新（端末内）':estimate.level!==3?'概算（試作・この端末）':(s.custom||hasManual)?'情報なし':'サンプル値'}
}
function persist(k,v){try{localStorage.setItem(k,JSON.stringify(v));return true}catch{toast('保存できません。ブラウザの保存設定を確認してください。');return false}}
function toast(t){$('toast').textContent=t;$('toast').hidden=false;clearTimeout(toast.timer);toast.timer=setTimeout(()=>$('toast').hidden=true,4500)}
let searchOrigin={lat:35.6909,lon:139.7003},filters={category:'',price:'',crowd:'available'};
let map,userMarker,position=null,watch=null,enabled=false,lastFix=0;const markers=new Map();
if(window.maplibregl){try{
 map=new maplibregl.Map({container:'map',style:'map-style.json',center:[searchOrigin.lon,searchOrigin.lat],zoom:14,dragRotate:false,touchPitch:false,attributionControl:false});
 map.addControl(new maplibregl.NavigationControl({showCompass:false}),'top-left');
 map.addControl(new maplibregl.AttributionControl({compact:false}),'bottom-right');
 map.touchZoomRotate.disableRotation();
 map.on('load',()=>{renderMap();ensureVacancyVisible()});
 map.on('error',()=>{$('location-status').textContent='地図を読み込めません。接続を確認してください。'});
}catch{$('map').textContent='このブラウザでは地図を表示できません。WebGLの設定を確認してください。'}}
function filtered(){return spots.map(data).filter(s=>(filters.crowd==='all'||s.level===0||(filters.crowd==='busy'&&s.level===1))&&(!filters.category||s.category===filters.category)&&(filters.price===''||(filters.price==='over'?s.price>2000:s.price<=Number(filters.price))))}
function updateCount(){const n=filtered().filter(s=>s.level===0&&distance(searchOrigin,s)<=1000).length;$('result-count').textContent=`1km以内・空き${n}件`;$('result-count').title='絞り込み条件に合う空き施設';}
function createFacilityPin(s){
 const node=document.createElement('button');node.type='button';node.className='pin'+(s.sponsored?' sponsor':'');node.style.setProperty('--pin-color',colors[s.level]);
 const icons={
  cafe:'<path d="M5 5h12v8a6 6 0 0 1-12 0V5Zm12 2h2a3 3 0 0 1 0 6h-2M4 21h16"/>',
  public:'<path d="m3 8 9-5 9 5H3Zm2 13h14M6 10v8m6-8v8m6-8v8"/>',
  laptop:'<rect x="4" y="4" width="16" height="12" rx="1"/><path d="M2 20h20"/>'
 };
 const icon=s.category==='カフェ'?icons.cafe:s.category==='コワーキング'?icons.laptop:icons.public;
 // SVG markup is constant; facility names are inserted separately as text only.
 node.innerHTML='<svg class="pin-shape" viewBox="0 0 100 130" preserveAspectRatio="none" aria-hidden="true"><path d="M50 129C28 106 1 83 1 47C1 21 19 1 50 1S99 21 99 47C99 83 72 106 50 129Z"/></svg><span class="pin-content"><svg class="pin-symbol" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">'+icon+'</svg></span>';
 if(s.sponsored){const name=document.createElement('span');name.className='pin-name';name.textContent=s.name;const pr=document.createElement('span');pr.className='pin-pr';pr.textContent='PR';node.querySelector('.pin-content').append(name,pr)}
 node.setAttribute('aria-label',`${s.name}・${levels[s.level]}${s.sponsored?'・広告掲載施設':''}`);node.title=`${s.name}・${s.category}・${levels[s.level]}・${s.source}`;
 return node;
}
function renderMap(){
 const list=filtered();updateCount();if(!map)return;
 markers.forEach(m=>m.remove());markers.clear();
 for(const s of list){
  const node=createFacilityPin(s);
  node.onclick=()=>detail(s.id);
  markers.set(s.id,new maplibregl.Marker({element:node,anchor:'bottom'}).setLngLat([s.lon,s.lat]).addTo(map));
 }
}
// Expand only after explicit search/filter/location actions, never while the user pans.
function ensureVacancyVisible(){
 if(!map||$('explore').hidden)return;
 const vacant=filtered().filter(s=>s.level===0);
 if(!vacant.length){$('location-status').textContent='条件に合う空き施設がありません。';return}
 const box=$('map').getBoundingClientRect();if(box.width<1||box.height<1)return;
 const mx=Math.min(85,box.width/4),top=Math.min(105,box.height/3),bottom=45;
 const visible=()=>vacant.some(s=>{const p=map.project([s.lon,s.lat]);return p.x>=mx&&p.x<=box.width-mx&&p.y>=top+(s.sponsored?150:48)&&p.y<=box.height-bottom});
 let expanded=false;
 for(let step=0;step<32&&!visible()&&map.getZoom()>0;step++){map.jumpTo({zoom:Math.max(0,map.getZoom()-.5)});expanded=true}
 if(!visible()){
  const c=map.getCenter(),nearest=vacant.reduce((a,b)=>distance({lat:c.lat,lon:c.lng},a)<distance({lat:c.lat,lon:c.lng},b)?a:b);
  map.fitBounds([[c.lng,c.lat],[nearest.lon,nearest.lat]],{padding:Math.min(90,box.width/4),duration:0,maxZoom:map.getZoom()});expanded=true;
 }
 $('location-status').textContent=expanded?'空き施設が見える範囲まで広げました。':'';
}
function searchCenter(lat,lon,zoom){searchOrigin={lat,lon};updateCount();if(map){map.jumpTo({center:[lon,lat],zoom});ensureVacancyVisible()}}
function detail(id){detailID=id;renderDetail();if(!$('detail').open)$('detail').showModal()}
function renderDetail(){if(!detailID)return;const s=data(spots.find(s=>s.id===detailID));$('detail-name').textContent=s.name;const root=$('detail-body');root.replaceChildren();
 for(const [title,value] of [['混雑状況',levels[s.level]+' · '+s.source],['住所',s.address||'未設定'],['種類',s.category],['値段帯（1人あたり）',s.price===0?'無料':s.price.toLocaleString('ja-JP')+'円'],['メニュー',s.menu||'未設定'],['営業時間',s.hours||'未設定'],['お知らせ',s.memo||'未設定']]){const h=document.createElement('h2'),p=document.createElement('p');h.textContent=title;p.textContent=value;root.append(h,p)}
 renderSignals(root,s);
}
function tab(name){document.querySelectorAll('.page').forEach(e=>e.hidden=e.id!==name);document.querySelectorAll('[data-tab]').forEach(b=>{if(b.dataset.tab===name)b.setAttribute('aria-current','page');else b.removeAttribute('aria-current')});if(name==='explore'){map?.resize();ensureVacancyVisible()}if(name==='facility')loadProfile();if(name==='history')renderVisits();window.scrollTo(0,0)}
document.querySelectorAll('[data-tab]').forEach(b=>b.onclick=()=>tab(b.dataset.tab));document.querySelectorAll('[data-close]').forEach(b=>b.onclick=()=>$(b.dataset.close).close());function openFilters(dialog,host){for(const k of ['category','price','crowd'])$(k).value=filters[k];$(host).append($('filter-form'));$(dialog).showModal()}
$('search-open').onclick=()=>openFilters('search-dialog','search-filters');$('filter-open').onclick=()=>openFilters('filter-dialog','filter-dialog');
function applyFilters(){filters=Object.fromEntries(['category','price','crowd'].map(k=>[k,$(k).value]));renderMap();ensureVacancyVisible();if(position&&$('nearby-list').childElementCount)nearby()}
$('filter-form').onsubmit=e=>{e.preventDefault();applyFilters();$('filter-dialog').close();$('search-dialog').close()};
$('filter-reset').onclick=()=>{for(const k of ['category','price','crowd'])$(k).value=k==='crowd'?'available':'';applyFilters()};
let lastSearch=0;const searchCache=new Map();$('search-form').onsubmit=async e=>{e.preventDefault();const q=$('query').value.trim();if(!q)return;if(Date.now()-lastSearch<1500)return;lastSearch=Date.now();$('search-submit').disabled=true;$('search-results').replaceChildren();$('search-status').textContent='検索中…';try{let results=searchCache.get(q);if(!results){const response=await fetch('https://photon.komoot.io/api/?'+new URLSearchParams({q,limit:'5'}),{signal:AbortSignal.timeout(12000)});if(!response.ok)throw Error('search');results=(await response.json()).features;searchCache.set(q,results)}$('search-status').textContent=results.length?'場所を選んでください。':'見つかりませんでした。駅名や地名を変えてください。';for(const result of results){const b=document.createElement('button');b.className='result';b.textContent=result.properties.name||q;const sub=document.createElement('small');sub.textContent=[result.properties.city,result.properties.state,result.properties.country].filter(Boolean).join(' / ');b.append(sub);b.onclick=()=>{applyFilters();const [lon,lat]=result.geometry.coordinates;recordSearch(lat,lon);searchCenter(lat,lon,14);$('area').textContent=result.properties.name||q;$('nearby-list').replaceChildren();$('search-dialog').close();};$('search-results').append(b)}}catch{$('search-status').textContent='検索サービスに接続できません。しばらくして再試行してください。'}finally{$('search-submit').disabled=false}};
function distance(a,b){const rad=Math.PI/180,dlat=(b.lat-a.lat)*rad,dlon=(b.lon-a.lon)*rad;const h=Math.sin(dlat/2)**2+Math.cos(a.lat*rad)*Math.cos(b.lat*rad)*Math.sin(dlon/2)**2;return 6371000*2*Math.atan2(Math.sqrt(h),Math.sqrt(1-h))}
function nearby(){if(!position){toast('「現在地から探す」を押してください。');return}const root=$('nearby-list');root.replaceChildren();const h=document.createElement('h2');h.textContent='3km以内の施設';root.append(h);const list=filtered().map(s=>({...s,dist:distance(position,s)})).filter(s=>s.dist<=3000).sort((a,b)=>a.dist-b.dist);if(!list.length){const p=document.createElement('p');p.textContent='この周辺に条件に合う施設はありません。';root.append(p)}for(const s of list){const b=document.createElement('button');b.className='result';b.textContent=`${s.name} · 約${Math.round(s.dist)}m`;b.onclick=()=>detail(s.id);root.append(b)}}
function locationError(){$('locate').disabled=false;interrupt('位置情報の取得エラー');$('location-status').textContent='位置情報を取得できません。許可しなくても駅名検索は使えます。';$('detect-status').textContent=enabled?'位置情報を取得できません。検知を停止して再試行してください。':'検知はオフです'}
$('locate').onclick=()=>{if(!navigator.geolocation){locationError();return}$('locate').disabled=true;$('location-status').textContent='取得中…';navigator.geolocation.getCurrentPosition(p=>{$('locate').disabled=false;position={lat:p.coords.latitude,lon:p.coords.longitude};if(map){if(userMarker)userMarker.remove();const dot=document.createElement('div');dot.className='user-location';dot.setAttribute('aria-label','現在地');userMarker=new maplibregl.Marker({element:dot}).setLngLat([position.lon,position.lat]).addTo(map);}searchCenter(position.lat,position.lon,15);$('area').textContent='現在地';nearby()},locationError,{enableHighAccuracy:true,timeout:15000,maximumAge:0})};
function populateFacilities(){const selected=$('facility-select').value;$('facility-select').replaceChildren();for(const s of spots.map(data)){const o=document.createElement('option');o.value=s.id;o.textContent=s.name;$('facility-select').append(o)}if(selected)$('facility-select').value=selected}
function selected(){return data(spots.find(s=>s.id===$('facility-select').value)||spots[0])}
function loadProfile(){creatingFacility=false;const s=selected();$('profile-form').reset();for(const k of ['name','address','menu','hours','memo'])$(k).value=s[k];$('facility-lat').value=s.lat;$('facility-lon').value=s.lon;$('facility-category').value=s.category;$('facility-price').value=s.price;verifiedAddress=s.address;addressVersion++;$('address-results').replaceChildren();$('address-status').textContent='';$('save-status').textContent='';$('profile-title').textContent='施設情報';$('profile-save').textContent='変更を保存';$('cancel-add').hidden=true;$('show-facility-map').hidden=false;$('facility-crowd').hidden=false;renderCrowd()}
function renderCrowd(){const s=selected();$('crowd-buttons').replaceChildren();levels.slice(0,3).forEach((label,i)=>{const b=document.createElement('button');b.textContent=(s.level===i?'✓　':'○　')+label;b.style.background=colors[i]+'16';b.style.color=colors[i];b.setAttribute('aria-pressed',s.level===i);b.onclick=()=>updateLevel(i);$('crowd-buttons').append(b)})}
function updateLevel(level){const s=selected(),next={...profiles,[s.id]:{...profiles[s.id],level,levelAt:Date.now()}};if(persist(key+'-profiles',next)){profiles=next;renderCrowd();renderMap();ensureVacancyVisible();toast('保存しました')}}$('unknown').onclick=()=>updateLevel(3);$('facility-select').onchange=loadProfile;
$('profile-form').onsubmit=e=>{e.preventDefault();saveFacility()};
function interrupt(reason){let changed=false;visits.forEach(v=>{if(v.end==null){v.end=v.last;v.reason=reason;changed=true}});if(changed)persist(key+'-visits',visits);renderVisits()}
function renderVisits(){const root=$('visits');root.replaceChildren();if(!visits.length){root.textContent='履歴はありません';return}for(const v of [...visits].reverse()){const card=document.createElement('article');card.className='card visit';const h=document.createElement('h3');h.textContent=v.name;card.append(h);for(const t of [`開始：${new Date(v.start).toLocaleString('ja-JP')}`,`終了：${v.end?new Date(v.end).toLocaleString('ja-JP'):'未確定'}`,`推定滞在時間：${Math.max(0,Math.floor(((v.end??v.last)-v.start)/1000))}秒`,v.reason||'周辺で観測中（最終観測までの時間）']){const p=document.createElement('p');p.textContent=t;card.append(p)}root.append(card)}}
function stop(reason){if(watch!==null)navigator.geolocation.clearWatch(watch);watch=null;interrupt(reason)}
function start(){if(!enabled||document.hidden)return;if(!navigator.geolocation){locationError();return}watch=navigator.geolocation.watchPosition(p=>{if(!enabled||document.hidden)return;const now=p.timestamp;if(Date.now()-now>15000||now<=lastFix)return;if(p.coords.accuracy>50){interrupt('位置精度不足による中断');$('detect-status').textContent='位置精度が不足しています。検知は保留中です。';return}if(lastFix&&now-lastFix>60000)interrupt('位置更新の途絶による中断');lastFix=now;const current={lat:p.coords.latitude,lon:p.coords.longitude};for(const s of spots.map(data)){const d=distance(current,s),v=visits.find(v=>v.spotID===s.id&&v.end==null);if(v){v.last=now;if(d-p.coords.accuracy>150){v.end=now;v.reason='周辺退出を検知'}}else if(d+p.coords.accuracy<=100){visits.push({spotID:s.id,name:s.name,start:now,last:now,end:null})}}if(!persist(key+'-visits',visits)){enabled=false;$('consent').checked=false;stop('保存エラーによる中断')}$('detect-status').textContent=enabled?'施設周辺を検知中（屋内入店は確認できません）':'保存エラーで停止しました';renderVisits();renderMap();if($('detail').open)renderDetail()},locationError,{enableHighAccuracy:true,maximumAge:0,timeout:15000})}
$('consent').onchange=()=>{if($('consent').checked){$('consent').checked=false;$('consent-dialog').showModal()}else{enabled=false;stop('同意撤回による中断');$('detect-status').textContent='検知はオフです'}};$('accept-consent').onclick=()=>{enabled=true;lastFix=0;$('consent').checked=true;$('consent-dialog').close();$('detect-status').textContent='位置情報の許可・取得を待っています…';start()};
$('clear-history').onclick=()=>{if(!confirm('検知を停止し、このブラウザの訪問履歴をすべて削除しますか？'))return;enabled=false;$('consent').checked=false;stop('削除');try{localStorage.removeItem(key+'-visits');visits=[];renderVisits();$('detect-status').textContent='検知はオフです'}catch{toast('削除できませんでした。')}};
function saveFacility(){
 const name=$('name').value.trim(),address=$('address').value.trim(),lat=Number($('facility-lat').value),lon=Number($('facility-lon').value),price=Number($('facility-price').value);
 if(!name||(creatingFacility&&!address)){toast('名前と住所を入力してください。');return}
 if(!validCoordinates({lat,lon})||!$('facility-lat').value||!$('facility-lon').value){toast('住所の候補から地図上の位置を選んでください。');return}
 if(address!==verifiedAddress){toast('変更した住所の位置を選び直してください。');return}
 if(!Number.isFinite(price)||price<0||price>1000000)return;
 const wasNew=creatingFacility,id=wasNew?'local-'+crypto.randomUUID():selected().id;
 const values={...profiles[id],name,address,lat,lon,price,category:$('facility-category').value,menu:$('menu').value,hours:$('hours').value,memo:$('memo').value,...(wasNew?{custom:true}:{} )};
 const next={...profiles,[id]:values};if(!persist(key+'-profiles',next))return;profiles=next;
 if(wasNew)spots.push({id,name,lat,lon,price,category:values.category,custom:true,level:3,sponsored:false});
 populateFacilities();$('facility-select').value=id;loadProfile();renderMap();$('save-status').textContent=wasNew?'追加しました。混雑状況は未設定です。':'保存しました。';
}
$('add-facility').onclick=()=>{creatingFacility=true;$('profile-form').reset();$('address-results').replaceChildren();$('address-status').textContent='';$('save-status').textContent='';verifiedAddress='';addressVersion++;$('facility-lat').value='';$('facility-lon').value='';$('profile-title').textContent='施設を追加';$('profile-save').textContent='追加して保存';$('cancel-add').hidden=false;$('show-facility-map').hidden=true;$('facility-crowd').hidden=true;$('profile-form').querySelector('details').open=true;$('name').focus()};
$('cancel-add').onclick=loadProfile;
$('address').oninput=()=>{addressVersion++;$('address-results').replaceChildren();$('address-status').textContent=''};
for(const k of ['facility-lat','facility-lon'])$(k).oninput=()=>{verifiedAddress=$('address').value.trim();addressVersion++;$('address-results').replaceChildren();$('address-status').textContent='入力した座標で保存します。'};
$('address-lookup').onclick=async()=>{
 const q=$('address').value.trim();if(!q){$('address-status').textContent='住所を入力してください。';return}
 const version=++addressVersion;$('address-lookup').disabled=true;$('address-status').textContent='住所を検索中…';$('address-results').replaceChildren();
 try{const response=await fetch('https://photon.komoot.io/api/?'+new URLSearchParams({q,limit:'5'}),{signal:AbortSignal.timeout(12000)});if(!response.ok)throw Error('lookup');const results=(await response.json()).features;if(version!==addressVersion)return;
 $('address-status').textContent=results.length?'位置を選んでください。':'候補がありません。住所を変えるか、緯度・経度を入力してください。';
 for(const result of results){const [lon,lat]=result.geometry?.coordinates||[];if(!validCoordinates({lat,lon}))continue;const b=document.createElement('button');b.type='button';b.className='result';const p=result.properties;b.textContent=[p.name,p.state,p.city,p.street,p.housenumber,p.country].filter(Boolean).join(' ');b.onclick=()=>{if(version!==addressVersion)return;$('facility-lat').value=lat;$('facility-lon').value=lon;verifiedAddress=q;$('address-results').replaceChildren();$('address-status').textContent='位置を選択しました。保存後に「地図で見る」で確認できます。'};$('address-results').append(b)}
 }catch{if(version===addressVersion)$('address-status').textContent='住所を検索できません。再試行するか、緯度・経度を入力してください。'}finally{$('address-lookup').disabled=false}
};
$('show-facility-map').onclick=()=>{const s=selected();filters={category:'',price:'',crowd:'all'};renderMap();tab('explore');searchOrigin={lat:s.lat,lon:s.lon};$('area').textContent=s.name;map?.jumpTo({center:[s.lon,s.lat],zoom:15});updateCount();detail(s.id)};
function writeSignal(id,patch){const next={...signals,[id]:{...signals[id],...patch}};if(!persist(key+'-signals',next))return false;signals=next;renderMap();return true}
function recordSearch(lat,lon){
 const now=Date.now(),next={...signals};let changed=false;
 for(const s of spots.map(data)){if(distance({lat,lon},s)>1000)continue;const previous=signals[s.id]||{};if(CrowdEstimate.recent(previous.searchAt,now,1800000))continue;next[s.id]={...previous,searchAt:now};changed=true}
 if(changed&&persist(key+'-signals',next)){signals=next;renderMap()}
}
function renderSignals(root,s){
 const e=evidence(s.id),panel=document.createElement('section');panel.className='evidence card';
 const h=document.createElement('h2');h.textContent='混雑の概算（試作）';panel.append(h);
 const result=document.createElement('p');result.textContent=e.level===3?'不明 · 新しい口コミが不足しています。':levels[e.level]+' · 信頼度は低め';panel.append(result);
 const note=document.createElement('p');note.className='small muted';note.textContent='このブラウザの情報だけを使用。他の利用者には共有されません。位置情報では屋内入店・着席を確認できません。';panel.append(note);
 const counts=document.createElement('p');counts.className='small';counts.textContent=`直近30分：周辺の場所検索 ${e.searched?1:0}回／行く予定 ${e.going?1:0}件／周辺検知 ${e.nearby?1:0}件。口コミ ${e.review?1:0}件（1時間以内）。`;panel.append(counts);
 const going=document.createElement('button');going.type='button';going.textContent=e.going?'行く予定を取り消す':'行きますよ';going.setAttribute('aria-pressed',String(e.going));going.onclick=()=>{if(writeSignal(s.id,{goingAt:e.going?null:Date.now()}))renderDetail()};panel.append(going);
 const form=document.createElement('form');form.className='review-form';
 const label=document.createElement('label');label.textContent='今の混み具合を投稿';const select=document.createElement('select');select.required=true;select.setAttribute('aria-label','口コミの混み具合');
 const empty=document.createElement('option');empty.value='';empty.textContent='選んでください';select.append(empty);levels.slice(0,3).forEach((text,i)=>{const o=document.createElement('option');o.value=i;o.textContent=text;select.append(o)});label.append(select);form.append(label);
 const commentLabel=document.createElement('label');commentLabel.textContent='口コミ（任意）';const comment=document.createElement('textarea');comment.rows=2;comment.maxLength=500;commentLabel.append(comment);form.append(commentLabel);
 const submit=document.createElement('button');submit.type='submit';submit.textContent='この端末に投稿';form.append(submit);
 form.onsubmit=event=>{event.preventDefault();if(select.value==='')return;if(writeSignal(s.id,{review:{level:Number(select.value),text:comment.value.trim(),at:Date.now()}}))renderDetail()};panel.append(form);
 if(e.review){const p=document.createElement('p');p.textContent=`直近の口コミ：${levels[e.review.level]} · ${new Date(e.review.at).toLocaleTimeString('ja-JP',{hour:'2-digit',minute:'2-digit'})}${e.review.text?' — '+e.review.text:''}`;panel.append(p)}
 const info=document.createElement('details'),summary=document.createElement('summary'),p=document.createElement('p');summary.textContent='概算の考え方';p.className='small';p.textContent='新しい口コミを重視し、同意済みの周辺検知・行く予定・周辺の場所検索を弱く加味します。検索は施設の1km以内を選んだ場合に30分に1回まで。同一ブラウザの口コミは上書きします。検索や予定だけで空き・満席と断定しません。施設側の更新は1時間優先します。';info.append(summary,p);panel.append(info);root.append(panel);
}
$('estimate-location').onchange=()=>{if($('estimate-location').checked){$('estimate-location').checked=false;$('estimate-consent').showModal()}else{allowEstimateLocation=false;renderMap()}};
$('accept-estimate').onclick=()=>{allowEstimateLocation=true;$('estimate-location').checked=true;$('estimate-consent').close();renderMap();toast('概算への利用を有効にしました。周辺検知がオンの間だけ使います。')};
$('clear-signals').onclick=()=>{if(!confirm('この端末の口コミ・検索・行く予定をリセットしますか？'))return;if(persist(key+'-signals',{})){signals={};renderMap();toast('概算の参考情報をリセットしました。')}};
setInterval(()=>{if(document.hidden)return;renderMap();if($('detail').open&&!$('detail').contains(document.activeElement))renderDetail()},60000);

document.addEventListener('visibilitychange',()=>{if(document.hidden)stop('画面非表示による中断');else if(enabled){lastFix=0;start()}});window.addEventListener('pagehide',()=>stop('ページ終了による中断'));interrupt('ページ終了による中断');populateFacilities();loadProfile();renderMap();
new ResizeObserver(()=>{document.documentElement.style.setProperty('--dock',$('dock').getBoundingClientRect().height+'px');map?.resize()}).observe($('dock'));if(!storageOK)toast('保存データを読み込めませんでした。ブラウザの設定を確認してください。');
