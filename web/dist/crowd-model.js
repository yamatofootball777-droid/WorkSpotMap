/* Experimental, single-browser evidence. No signal implies no knowledge, not vacancy. */
(function(root){
 const HOUR=60*60*1000;
 function recent(at,now,ttl){return Number.isFinite(at)&&at<=now&&now-at<ttl}
 function estimate(signal={},visits=[],id,allowLocation=false,now=Date.now()){
  const review=signal.review&&[0,1,2].includes(signal.review.level)&&recent(signal.review.at,now,HOUR)?signal.review:null;
  const going=recent(signal.goingAt,now,HOUR/2),searched=recent(signal.searchAt,now,HOUR/2);
  const nearby=allowLocation&&visits.some(v=>v.spotID===id&&v.end==null&&recent(v.last,now,60000));
  let level=3,score=null;
  if(review){let weighted=review.level/2*4,weight=4;
   if(nearby){weighted+=.65;weight+=1}
   if(going){weighted+=.5*.5;weight+=.5}
   if(searched){weighted+=.25*.25;weight+=.25}
   score=weighted/weight;level=score<.33?0:score<.75?1:2;
  }
  return {level,review,going,searched,nearby,score};
 }
 root.CrowdEstimate={estimate,recent};
 if(typeof module!=='undefined')module.exports=root.CrowdEstimate;
})(globalThis);
