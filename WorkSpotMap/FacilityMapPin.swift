import SwiftUI

/// The fixed frame ends at the pin tip. Map annotations use `.bottom` as their anchor.
struct FacilityMapPin: View {
    let spot: Spot

    private var sponsored: Bool { spot.isSponsored }
    private var width: CGFloat { sponsored ? 116 : 36 }
    private var height: CGFloat { sponsored ? 150 : 48 }
    private var symbol: String {
        switch spot.category {
        case .cafe: "cup.and.saucer.fill"
        case .library, .study: "building.columns.fill"
        case .coworking: "laptopcomputer"
        }
    }

    var body: some View {
        ZStack(alignment: .top) {
            FacilityPinShape()
                .fill(spot.crowd.tint)
            FacilityPinShape()
                .stroke(.white, lineWidth: 2)
                .clipShape(FacilityPinShape())
            if sponsored {
                VStack(spacing: 5) {
                    Image(systemName: symbol)
                        .font(.system(size: 24, weight: .semibold))
                        .frame(height: 29)
                    Text(spot.name)
                        .font(.system(size: 12, weight: .bold))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .truncationMode(.tail)
                        .frame(width: 92, height: 32)
                        .clipped()
                    Text("PR")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(spot.crowd.tint)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(.white, in: RoundedRectangle(cornerRadius: 4))
                }
                .foregroundStyle(.white)
                .padding(.top, 15)
            } else {
                Image(systemName: symbol)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: width, height: 34)
            }
        }
        .frame(width: width, height: height)
        .clipShape(FacilityPinShape())
        .contentShape(FacilityPinShape())
        .shadow(color: .black.opacity(0.22), radius: 2, y: 1)
        // Fixed typography keeps all content inside the pin even at accessibility text sizes.
        // The enclosing button exposes the full, untruncated facility name to VoiceOver.
        .dynamicTypeSize(.medium)
    }
}

struct FacilityPinShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        var p = Path()
        p.move(to: CGPoint(x: w * 0.5, y: h))
        p.addCurve(to: CGPoint(x: 0, y: h * 0.36),
                   control1: CGPoint(x: w * 0.28, y: h * 0.82),
                   control2: CGPoint(x: 0, y: h * 0.64))
        p.addCurve(to: CGPoint(x: w * 0.5, y: 0),
                   control1: CGPoint(x: 0, y: h * 0.16),
                   control2: CGPoint(x: w * 0.19, y: 0))
        p.addCurve(to: CGPoint(x: w, y: h * 0.36),
                   control1: CGPoint(x: w * 0.81, y: 0),
                   control2: CGPoint(x: w, y: h * 0.16))
        p.addCurve(to: CGPoint(x: w * 0.5, y: h),
                   control1: CGPoint(x: w, y: h * 0.64),
                   control2: CGPoint(x: w * 0.72, y: h * 0.82))
        p.closeSubpath()
        return p.offsetBy(dx: rect.minX, dy: rect.minY)
    }
}

#Preview("通常・スポンサー / 全混雑色") {
    ScrollView {
        ForEach(CrowdLevel.allCases) { crowd in
            HStack(alignment: .bottom, spacing: 16) {
                ForEach(SpotCategory.allCases) { category in
                    FacilityMapPin(spot: Spot(id: UUID(), name: "施設名", category: category,
                        latitude: 0, longitude: 0, address: "", note: "", hasWifi: false,
                        hasPower: false, crowd: crowd))
                }
                FacilityMapPin(spot: Spot(id: UUID(), name: "とても長い施設名のあきどこサンプルカフェ新宿駅前店",
                    category: .cafe, latitude: 0, longitude: 0, address: "", note: "",
                    hasWifi: false, hasPower: false, crowd: crowd, isSponsored: true))
            }
        }
    }.padding()
}
