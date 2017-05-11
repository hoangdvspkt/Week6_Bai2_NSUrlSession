//
//  Download.swift
//  HalfTunes
//
//  Created by ronatory on 07.11.16.
//  Copyright © 2016 ronatory. All rights reserved.
//

import Foundation

class Download: NSObject {
  

  var url: String
  var isDownloading = false

  var progress: Float = 0.0

  var downloadTask: URLSessionDownloadTask?

  var resumeData: NSData?
  
  init(url: String) {
    self.url = url
  }
}
