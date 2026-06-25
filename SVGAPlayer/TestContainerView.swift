//
//  TestContainerView.swift
//  SVGAPlayer
//
//  Created by dadadongl on 2026/6/25.
//  Copyright © 2026 UED Center. All rights reserved.
//

import UIKit

@objc class TestContainerView: UIView {
    private lazy var testLabel: UILabel = {
        let ss = UILabel()
        ss.backgroundColor = UIColor.orange.withAlphaComponent(0.8)
        ss.text = "哈哈😄哈哈"
        ss.textAlignment = .center
        return ss

    }()

    private lazy var svga: TPSVGABridgeView = {
        let ss = TPSVGABridgeView(with: testLabel, size: CGSize(width: 50, height: 50), svgaFileName: "test2")
        return ss
    }()

    @objc func run() {
        addSubview(svga)
        svga.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        svga.start(with: 2) { [weak self] state in
            switch state {
            case .didStart:
                print("开始了")
            case .didEnd:
                self?.svga.removeFromSuperview()
            }
        }
    }
}
