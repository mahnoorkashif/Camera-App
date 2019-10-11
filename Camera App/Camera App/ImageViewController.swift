//
//  ImageViewController.swift
//  Camera App
//
//  Created by Mahnoor Khan on 11/10/2019.
//  Copyright © 2019 Mahnoor Khan. All rights reserved.
//

import UIKit

class ImageViewController: UIViewController {

    @IBOutlet weak var imageView        : UIImageView!
    
    var image: UIImage?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        imageView.image = image
    }
}
