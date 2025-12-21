import SwiftUI

struct CountdownView: View {
    // 표시할 텍스트 (예: "3", "2", "시작!")
    var text: String
    
    // 텍스트가 바뀔 때마다 부드러운 애니메이션 효과
    @State private var scale: CGFloat = 1.0
    
    var body: some View {
        Text(text)
            .font(.system(size: 80, weight: .bold, design: .rounded))
            .scaleEffect(scale)
            .onAppear {
                // 뷰가 나타날 때마다 크기를 살짝 키우는 효과
                withAnimation(.easeOut(duration: 0.3)) {
                    scale = 1.2
                }
                // 곧바로 원래 크기로 복귀
                withAnimation(.easeOut(duration: 0.3).delay(0.3)) {
                    scale = 1.0
                }
            }
            // text 값이 바뀔 때마다 애니메이션을 다시 트리거
            .id(text)
    }
}
