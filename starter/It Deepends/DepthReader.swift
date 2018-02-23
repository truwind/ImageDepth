/**
 * Copyright (c) 2017 Razeware LLC
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * Notwithstanding the foregoing, you may not use, copy, modify, merge, publish,
 * distribute, sublicense, create a derivative work, and/or sell copies of the
 * Software in any work that is designed, intended, or marketed for pedagogical or
 * instructional purposes related to programming, coding, application development,
 * or information technology.  Permission for such use, copying, modification,
 * merger, publication, distribution, sublicensing, creation of derivative works,
 * or sale is expressly withheld.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

#if !IOS_SIMULATOR
import AVFoundation

struct DepthReader {
  
  var name: String
  var ext: String

  func depthDataMap() -> CVPixelBuffer? {
    // First, you get a URL for an image file and safely type cast it to a CFURL.
    guard let fileURL = Bundle.main.url(forResource: name, withExtension: ext) as CFURL? else {
      return nil
    }
    // You then create a CGImageSource from this file.
    guard let source = CGImageSourceCreateWithURL(fileURL, nil) else {
      return nil
    }
    
    /**
     * From the image source at index 0, you copy the disparity data (more on what that means later,
       but you can think of it as depth data for now) from its auxiliary data.
       The index is 0 because there is only one image in the image source.
       iOS knows how to extract the data from JPGs and HEIC files alike,
       but unfortunately this doesn’t work in the simulator.
     */
    guard let auxDataInfo = CGImageSourceCopyAuxiliaryDataInfoAtIndex(source, 0, kCGImageAuxiliaryDataTypeDisparity) as? [AnyHashable : Any] else {
      return nil
    }
    
    // You prepare a property for the depth data. As previously mentioned,
    // you use AVDepthData to extract the auxiliary data from an image.
    var depthData: AVDepthData
    
    do {
      // You create an AVDepthData entity from the auxiliary data you read in.
      depthData = try AVDepthData(fromDictionaryRepresentation: auxDataInfo)
      
    } catch {
      return nil
    }
    
    // You ensure the depth data is the the format you need: 32-bit floating point disparity information.
    if depthData.depthDataType != kCVPixelFormatType_DisparityFloat32 {
      depthData = depthData.converting(toDepthDataType: kCVPixelFormatType_DisparityFloat32)
    }
    
    return depthData.depthDataMap
  }
}
  
/**
 * struct를 ObjectiveC로 bridging할 수 없으므로 아래와 같이 wrap을 한다.
 * http://blog.benjamin-encz.de/post/bridging-swift-types-to-objective-c/
 */
@objc class DepthReaderObj: NSObject {
  // The underlying Swift type is stored in the bridged type. This way
  // Swift code that consumes the bridged Objective-C type can pull out and
  // use the underlying Swift type.
  private (set) var depthReader: DepthReader
  
  class func depthDataMapClassFunc(name: String, ext: String) -> CVPixelBuffer? {
    let depthReader = DepthReader(name: name, ext: ext)
    return depthReader.depthDataMap()
  }

  
  public init(name: String, ext: String) {
    // All initializers construct the underlying Swift type
    self.depthReader = DepthReader(name: name, ext: ext)
  }
  
  // This initializer allows Swift code to create a bridged value and pass
  // it to Objective-C code.
  public init(depthReader: DepthReader) {
    self.depthReader = depthReader
  }

  // Computed properties are implemented based on properties of the
  // underlying Swift type.
  var name: String {
    get {
      return depthReader.name
    }
    set {
      self.depthReader.name = newValue
    }
  }
  
  var ext: String {
    get {
      return depthReader.ext
    }
    set {
      self.depthReader.ext = newValue
    }
  }
  
  public func depthDataMap() -> CVPixelBuffer? {
    return self.depthReader.depthDataMap()
  }
}
#endif

