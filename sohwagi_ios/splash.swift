//
//  File.swift
//  sohwagi_ios
//
//  Created by 구나연 on 12/25/24.
//

import SwiftUI

struct LaunchView: View {
    var body: some View {
        ZStack {
            // 배경색 설정 (HEX #2B323C)
            Color(red: 0.17, green: 0.2, blue: 0.24) // 2B323C에 해당하는 RGB 값
                .ignoresSafeArea() // Safe Area까지 색상이 확장되도록 설정
            
            // 이미지 설정
            Image("hamtori")
                .resizable() // 이미지 크기를 조정 가능하게 만듦
                .scaledToFit() // 이미지 비율을 유지하며 크기를 조정
                .frame(width: 102, height: 102) // 이미지 크기 조정
        }
    }
}

#Preview {
    LaunchView()
}
