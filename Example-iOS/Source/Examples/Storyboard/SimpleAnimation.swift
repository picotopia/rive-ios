//
//  SimpleAnimation.swift
//  RiveExample
//
//  Created by Maxwell Talbot on 06/05/2021.
//  Copyright © 2021 Rive. All rights reserved.
//

import UIKit
import RiveRuntime
import SwiftUI

class SimpleAnimationViewController: UIViewController {
    var viewModel = RiveViewModel(fileName: "pico")
    
    override func viewWillAppear(_ animated: Bool) {
      try! viewModel.configureModel(animationName: "Cluster2")
        let riveView = viewModel.createRiveView()
        view.addSubview(riveView)
        riveView.frame = view.frame
      
      riveView.backgroundColor = .clear
      view.backgroundColor = .blue
    }
}
