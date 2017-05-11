//
//  SearchViewController.swift
//  HalfTunes
//
//  Created by Ken Toh on 13/7/15.
//  Copyright (c) 2015 Ken Toh. All rights reserved.
//  hoangdv

import UIKit
import MediaPlayer

class SearchViewController: UIViewController {
  
  @IBOutlet weak var tableView: UITableView!
  @IBOutlet weak var searchBar: UISearchBar!
  
  var searchResults = [Track]()
  

  let defaultSession = URLSession(configuration: URLSessionConfiguration.default)

  var dataTask: URLSessionDataTask?
  

  var activeDownloads = [String: Download]()
  
  lazy var tapRecognizer: UITapGestureRecognizer = {
    var recognizer = UITapGestureRecognizer(target:self, action: #selector(SearchViewController.dismissKeyboard))
    return recognizer
  }()
  

  lazy var downloadsSession: URLSession = {

    let configuration = URLSessionConfiguration.background(withIdentifier: "bgSessionConfiguration")
    let session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
    return session
  }()
 
  
  override func viewDidLoad() {
    super.viewDidLoad()
    tableView.tableFooterView = UIView()

    _ = self.downloadsSession
  }
  
  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
  }
  
  // MARK: Handling Search Results
  
  // This helper method helps parse response JSON NSData into an array of Track objects.
  func updateSearchResults(_ data: Data?) {
    searchResults.removeAll()
    do {
      if let data = data, let response = try JSONSerialization.jsonObject(with: data, options:JSONSerialization.ReadingOptions(rawValue:0)) as? [String: AnyObject] {
        
        // Get the results array
        if let array: AnyObject = response["results"] {
          for trackDictonary in array as! [AnyObject] {
            if let trackDictonary = trackDictonary as? [String: AnyObject], let previewUrl = trackDictonary["previewUrl"] as? String {
              // Parse the search result
              let name = trackDictonary["trackName"] as? String
              let artist = trackDictonary["artistName"] as? String
              searchResults.append(Track(name: name, artist: artist, previewUrl: previewUrl))
            } else {
              print("Not a dictionary")
            }
          }
        } else {
          print("Results key not found in dictionary")
        }
      } else {
        print("JSON Error")
      }
    } catch let error as NSError {
      print("Error parsing results: \(error.localizedDescription)")
    }
    
    DispatchQueue.main.async {
      self.tableView.reloadData()
      self.tableView.setContentOffset(CGPoint.zero, animated: false)
    }
  }
  
  // MARK: Keyboard dismissal
  
  func dismissKeyboard() {
    searchBar.resignFirstResponder()
  }
  
  // MARK: Download methods
  
  func startDownload(_ track: Track) {
    if let urlString = track.previewUrl, let url = URL(string: urlString) {

      let download = Download(url: urlString)

      download.downloadTask = downloadsSession.downloadTask(with: url)

      download.downloadTask!.resume()

      download.isDownloading = true

      activeDownloads[download.url] = download
    }
  }
  

  func pauseDownload(_ track: Track) {
    if let urlString = track.previewUrl, let download = activeDownloads[urlString] {
      if download.isDownloading {

        download.downloadTask?.cancel(byProducingResumeData: { data in
          if data != nil {
            download.resumeData = data as NSData?
          }
        })

        download.isDownloading = false
      }
    }
  }
  
  // Called when the Cancel button for a track is tapped
  func cancelDownload(_ track: Track) {
    if let urlString = track.previewUrl, let download = activeDownloads[urlString] {
      // call cancel on the corresponding Download in the dictionary of active downloads
      download.downloadTask?.cancel()
      // you then remove it from the dictionary of active downloads
      activeDownloads[urlString] = nil
    }
  }
  
  // Called when the Resume button for a track is tapped
  func resumeDownload(_ track: Track) {
    if let urlString = track.previewUrl, let download = activeDownloads[urlString] {
      // is resume data present
      if let resumeData = download.resumeData {
        download.downloadTask = downloadsSession.downloadTask(withResumeData: resumeData as Data)
        download.downloadTask!.resume()
        download.isDownloading = true
      } else if let url = URL(string: download.url) {
        download.downloadTask = downloadsSession.downloadTask(with: url)
        download.downloadTask!.resume()
        download.isDownloading = true
      }
    }
  }
  
  // This method attempts to play the local file (if it exists) when the cell is tapped
  func playDownload(_ track: Track) {
    if let urlString = track.previewUrl, let url = localFilePathForUrl(urlString) {
      let moviePlayer:MPMoviePlayerViewController! = MPMoviePlayerViewController(contentURL: url)
      presentMoviePlayerViewControllerAnimated(moviePlayer)
    }
  }
  
  // MARK: Download helper methods

  func localFilePathForUrl(_ previewUrl: String) -> URL? {
    let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0] as NSString
    if let url = URL(string: previewUrl) {
      //      , let lastPathComponent = url.lastPathComponent
      let fullPath = documentsPath.appendingPathComponent(url.lastPathComponent)
      return URL(fileURLWithPath:fullPath)
    }
    return nil
  }
  

  func localFileExistsForTrack(_ track: Track) -> Bool {
    if let urlString = track.previewUrl, let localUrl = localFilePathForUrl(urlString) {
      var isDir : ObjCBool = false
      //      if let path = localUrl.path {
      return FileManager.default.fileExists(atPath: localUrl.path, isDirectory: &isDir)
      //      }
    }
    return false
  }
  
  // simply returns the index of the Track in the searchResults list that has the given URL
  func trackIndexForDownloadTask(downloadTask: URLSessionDownloadTask) -> Int? {
    if let url = downloadTask.originalRequest?.url?.absoluteString {
      for (index, track) in searchResults.enumerated() {
        if url == track.previewUrl! {
          return index
        }
      }
    }
    return nil
  }
}

// MARK: - UISearchBarDelegate

extension SearchViewController: UISearchBarDelegate {
  func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
    // Dimiss the keyboard
    dismissKeyboard()
    
    if !searchBar.text!.isEmpty {

      if dataTask != nil {
        dataTask?.cancel()
      }

      UIApplication.shared.isNetworkActivityIndicatorVisible = true

      let expectedCharSet = NSCharacterSet.urlQueryAllowed
      let searchTerm = searchBar.text!.addingPercentEncoding(withAllowedCharacters: expectedCharSet)!

      let url = URL(string: "https://itunes.apple.com/search?media=music&entity=song&term=\(searchTerm)")

      dataTask = defaultSession.dataTask(with: url!) {
        data, response, error in

        DispatchQueue.main.async {
          UIApplication.shared.isNetworkActivityIndicatorVisible = false
        }

        if let error = error {
          print(error.localizedDescription)
        } else if let httpResponse = response as? HTTPURLResponse {
          if httpResponse.statusCode == 200 {
            self.updateSearchResults(data)
          }
        }
      }

      dataTask?.resume()
    }
  }
  
  func position(for bar: UIBarPositioning) -> UIBarPosition {
    return .topAttached
  }
  
  func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
    view.addGestureRecognizer(tapRecognizer)
  }
  
  func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
    view.removeGestureRecognizer(tapRecognizer)
  }
}

// MARK: TrackCellDelegate

extension SearchViewController: TrackCellDelegate {
  func pauseTapped(_ cell: TrackCell) {
    if let indexPath = tableView.indexPath(for: cell) {
      let track = searchResults[indexPath.row]
      pauseDownload(track)
      tableView.reloadRows(at: [IndexPath(row: indexPath.row, section: 0)], with: .none)
    }
  }
  
  func resumeTapped(_ cell: TrackCell) {
    if let indexPath = tableView.indexPath(for: cell) {
      let track = searchResults[indexPath.row]
      resumeDownload(track)
      tableView.reloadRows(at: [IndexPath(row: indexPath.row, section: 0)], with: .none)
    }
  }
  
  func cancelTapped(_ cell: TrackCell) {
    if let indexPath = tableView.indexPath(for: cell) {
      let track = searchResults[indexPath.row]
      cancelDownload(track)
      tableView.reloadRows(at: [IndexPath(row: indexPath.row, section: 0)], with: .none)
    }
  }
  
  func downloadTapped(_ cell: TrackCell) {
    if let indexPath = tableView.indexPath(for: cell) {
      let track = searchResults[indexPath.row]
      startDownload(track)
      tableView.reloadRows(at: [IndexPath(row: indexPath.row, section: 0)], with: .none)
    }
  }
}

// MARK: UITableViewDataSource

extension SearchViewController: UITableViewDataSource {
  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return searchResults.count
  }
  
  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCell(withIdentifier: "TrackCell", for: indexPath) as!TrackCell
    
    // Delegate cell button tap events to this view controller
    cell.delegate = self
    
    let track = searchResults[indexPath.row]
    
    // Configure title and artist labels
    cell.titleLabel.text = track.name
    cell.artistLabel.text = track.artist
    

    var showDownloadControls = false
    if let download = activeDownloads[track.previewUrl!] {
      showDownloadControls = true
      
      cell.progressView.progress = download.progress
      cell.progressLabel.text = (download.isDownloading) ? "Downloading..." : "Paused"
      
      // this toggles the button between the two states pause and resume
      let title = (download.isDownloading) ? "Pause" : "Resume"
      cell.pauseButton.setTitle(title, for: UIControlState.normal)
    }
    cell.progressView.isHidden = !showDownloadControls
    cell.progressLabel.isHidden = !showDownloadControls
    

    let downloaded = localFileExistsForTrack(track)
    cell.selectionStyle = downloaded ? UITableViewCellSelectionStyle.gray : UITableViewCellSelectionStyle.none
    
    // hide the Download button also if its track is downloading
    cell.downloadButton.isHidden = downloaded || showDownloadControls
    
    // show the pause and cancel buttons only if a download is active
    cell.pauseButton.isHidden = !showDownloadControls
    cell.cancelButton.isHidden = !showDownloadControls
    
    return cell
  }
}

// MARK: UITableViewDelegate

extension SearchViewController: UITableViewDelegate {
  func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
    return 62.0
  }
  
  func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    let track = searchResults[indexPath.row]
    if localFileExistsForTrack(track) {
      playDownload(track)
    }
    tableView.deselectRow(at: indexPath, animated: true)
  }
}

// MARK: URLSessionDownloadDelegate

extension SearchViewController: URLSessionDownloadDelegate {
  func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {

    if let originalURL = downloadTask.originalRequest?.url?.absoluteString, let destinationURL = localFilePathForUrl(originalURL) {
      print(destinationURL)
      

      let fileManager = FileManager.default
      do {
        try fileManager.removeItem(at: destinationURL)
      } catch {
        // Non-fatal: file probably doesn't exist
      }
      do {
        try fileManager.copyItem(at: location, to: destinationURL)
      } catch let error as NSError {
        print("Could not copy file to disk: \(error.localizedDescription)")
      }
    }
    

    if let url = downloadTask.originalRequest?.url?.absoluteString {
      activeDownloads[url] = nil

      if let trackIndex = trackIndexForDownloadTask(downloadTask: downloadTask) {
        DispatchQueue.main.async {
          self.tableView.reloadRows(at: [IndexPath(row: trackIndex, section: 0)], with: .none)
        }
      }
    }
  }
  
  func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {

    if let downloadUrl = downloadTask.originalRequest?.url?.absoluteString, let download = activeDownloads[downloadUrl] {

      download.progress = Float(totalBytesWritten)/Float(totalBytesExpectedToWrite)

      let totalSize = ByteCountFormatter.string(fromByteCount: totalBytesExpectedToWrite, countStyle: ByteCountFormatter.CountStyle.binary)

      if let trackIndex = trackIndexForDownloadTask(downloadTask: downloadTask), let trackCell = tableView.cellForRow(at: IndexPath(row: trackIndex, section: 0)) as? TrackCell {
        DispatchQueue.main.async {
          trackCell.progressView.progress = download.progress
          trackCell.progressLabel.text = String(format: "%.1f%% of %@", download.progress * 100, totalSize)
        }
      }
    }
  }
}

// MARK: URLSessionDelegate
extension SearchViewController: URLSessionDelegate {
  func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
    if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
      if let completionHandler = appDelegate.backgroundSessionCompletionHandler {
        appDelegate.backgroundSessionCompletionHandler = nil
        DispatchQueue.main.async {
          completionHandler()
        }
      }
    }
  }
}

