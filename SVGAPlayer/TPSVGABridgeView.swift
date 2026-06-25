//
//  TPSVGABridgeView.swift
//  SVGAPlayer
//
//  Created by dadadongl on 2026/6/24.
//  Copyright © 2026 UED Center. All rights reserved.
//

import SnapKit
import UIKit

class TPSVGABridgeView: UIView {
    enum PlayState {
        case didStart
        case didEnd
    }

    override var intrinsicContentSize: CGSize {
        return __contentSize
    }

    let snapView: UIView
    let svgaFileName: String

    init(with snap: UIView, size: CGSize, svgaFileName: String) {
        self.svgaFileName = svgaFileName
        snapView = snap
        snap.frame = CGRect(origin: .zero, size: size)
        snap.layer.masksToBounds = true

        super.init(frame: .zero)
        // 动效设计尺寸340, 头像空位尺寸246
        assert(size.width > 0 && size.width == size.height, "必须是正方形")
        let w = Int(Float(CGFloat(246) / size.width * CGFloat(340)).nextUp)
        __contentSize = CGSize(width: w, height: w)
        //
        isUserInteractionEnabled = false
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private var __contentSize = CGSize.zero
    private let svgaPlayer = SVGAImageView()
    private var __callback: ((PlayState) -> Void)?
    private var __totalLoops = 1
    private var __curPlayCount = 0

    // 只能调用一次
    func start(with loops: Int, callBack: @escaping (PlayState) -> Void) {
        assert(loops >= 1, "")
        __totalLoops = loops

        __callback = callBack
        svgaPlayer.imageName = svgaFileName
    }

    private func setup() {
        snapView.isUserInteractionEnabled = false
        addSubview(snapView)
        snapView.center = CGPoint(x: __contentSize.width / 2, y: __contentSize.height / 2)

        svgaPlayer.delegate = self
        svgaPlayer.autoPlay = true
        svgaPlayer.contentMode = .scaleToFill
        svgaPlayer.loops = 0 // 无限次
        svgaPlayer.isUserInteractionEnabled = true
        addSubview(svgaPlayer)
        svgaPlayer.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        // 监听绘制回调
        svgaPlayer.setDrawing({ [weak self] contentLayer, _, frameItem in
            guard let self = self, let contentLayer = contentLayer, let frameItem = frameItem else { return }

            if contentLayer.isHidden || frameItem.alpha <= 0.0 {
                self.snapView.isHidden = true
                return
            }
            self.snapView.isHidden = false

            // 1) 还原旋转/缩放:只取线性部分(平移交给 center,否则会和 center 重复叠加导致错位)
            //    自身 transform 的旋转/缩放,再叠上 drawLayer(设计坐标系→播放器坐标系)的缩放
            var t = frameItem.transform
            t.tx = 0; t.ty = 0
            var p = contentLayer.superlayer!.affineTransform() // superlayer 即 drawLayer
            p.tx = 0; p.ty = 0
            t = CGAffineTransformConcat(t, p)

            // 2) 还原大小:bounds 用设计尺寸(= layout.size),缩放已在 transform 里,避免重复缩放
            self.snapView.bounds = contentLayer.bounds
            self.snapView.transform = t
            // 修正圆角半径
            self.snapView.layer.cornerRadius = contentLayer.bounds.height / 2

            // 3) 还原位置:把 contentLayer 的中心点换算到播放器坐标系(已含所有平移:drawLayer offset / frameItem 平移 / nx-ny 补偿)
            let localCenter = CGPointMake(CGRectGetMidX(contentLayer.bounds),
                                          CGRectGetMidY(contentLayer.bounds))
//            self.snapView.center = [self.aPlayer.layer convertPoint:localCenter fromLayer:contentLayer];

            self.snapView.center = self.svgaPlayer.layer.convert(localCenter, from: contentLayer)

        }, forKey: "head")
    }
}

extension TPSVGABridgeView: SVGAPlayerDelegate {
    // 之前想的是播放循环次数设置为1, 每次结束后 决定是否再次继续播放
    // 但是这个方案 可能出现闪烁
    // 现在改成了:  播放次数设置为无线, 当播放到总次数+1的第一帧时, 强行结束播放 (是否也会出现闪烁??? 测试后再决定用哪种)

//    func svgaPlayerDidFinishedAnimation(_ player: SVGAPlayer!) {
//        if __curPlayCount == __totalLoops {
//            // 结束
//            __callback?(.didEnd)
//            __callback = nil
//        } else {
//            // 继续播
//            player.startAnimation()
//        }
//    }

    func svgaPlayerDidAnimated(toFrame frame: Int) {
        if frame == 1 {
            __curPlayCount += 1
            if __curPlayCount == 1 {
                // 开始
                __callback?(.didStart)
            } else if __curPlayCount == __totalLoops + 1 {
                // 结束
                __callback?(.didEnd)
                __callback = nil
            }
        }
    }
}
