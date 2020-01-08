import Foundation
import THEOplayerSDK
class ContentId{
    var broadcasterId: Int
    var mediaId: Int
    var contentType: String
    
    init(contentIdStr: String) {
        let split = contentIdStr.split(separator: "_")
        
        self.broadcasterId = Int(split[0])!
        self.mediaId = Int(split[2])!
        self.contentType = String(split[1])
    }
    
    
    func toUrl() -> String{
        return String(self.broadcasterId) + "/" + self.contentType + "/" + String(self.mediaId)
    }
}

extension UIImageView {
    func downloadedFrom(url: URL, contentMode mode: UIView.ContentMode = .scaleAspectFit) {
        contentMode = mode
        URLSession.shared.dataTask(with: url) { data, response, error in
            guard
                let httpURLResponse = response as? HTTPURLResponse, httpURLResponse.statusCode == 200,
                let mimeType = response?.mimeType, mimeType.hasPrefix("image"),
                let data = data, error == nil,
                let image = UIImage(data: data)
                else { return }
            DispatchQueue.main.async() {
                self.image = image
            }
            }.resume()
    }
    func downloadedFrom(link: String, contentMode mode: UIView.ContentMode = .scaleAspectFit) {
        guard let url = URL(string: link) else { return }
        downloadedFrom(url: url, contentMode: mode)
    }
}

public class DacastPlayer{
    
    public var frame: CGRect{
        get{
            return self.view.frame
        }
        
        set(value){
            self.view.frame = value
            self.theoplayer.frame = value
            self.watermarkImg.frame = CGRect(x: value.minX + 5, y: value.minY + 5, width: value.width * 0.3, height: value.height * 0.3)
        }
    }
    
    let theoplayer: THEOplayer
    let view: UIView
    let watermarkImg: UIImageView
    let adUrl: String?
    
    public init(contentIdStr: String, adUrl: String? = nil) {
        self.adUrl = adUrl
        
        let contentId = ContentId(contentIdStr: contentIdStr)
        
        view = UIView()
        
        let playerConfig = THEOplayerConfiguration(googleIMA: adUrl != nil)
        self.theoplayer = THEOplayer(configuration: playerConfig)
        theoplayer.insertAsSubview(of: view, at: 0)
        
        watermarkImg = UIImageView()
        watermarkImg.isOpaque = false
        watermarkImg.alpha = 0.3
        view.insertSubview(watermarkImg, at: 9990000)
        
        populatePlayerInfo(contentId: contentId)
    }
    
    public func addAsSubview(of: UIView){
        of.addSubview(view)
    }
    
    public func insertAsSubview(of: UIView, at: Int){
        of.insertSubview(view, at: at)
    }
    
    public func getTHEOplayer() -> THEOplayer{
        return theoplayer
    }
    
    private func populatePlayerInfo(contentId: ContentId){
        makeGetCall(endpoint: "https://json.dacast.com/b/" + contentId.toUrl()){
            jsonData in
            
            self.makeGetCall(endpoint: "https://services.dacast.com/token/i/b/" + contentId.toUrl()){
                serviceData in
                
                var m3u8Link: String = jsonData["hls"] as! String
                m3u8Link += serviceData["token"] as! String
                let streamData = jsonData["stream"] as! [String : Any]
                let splashLink = streamData["splash"] as! String
                let themeData = jsonData["theme"] as! [String : Any]
                let watermarkData = themeData["watermark"] as! [String : Any]
                let watermarkLink = watermarkData["url"]
                
                DispatchQueue.main.async {
                    if !(watermarkLink is NSNull) && watermarkLink != nil {
                        self.watermarkImg.downloadedFrom(link: "https:" + (watermarkLink as! String))
                    }
                    let typedSource = TypedSource(src: m3u8Link, type: "application/x-mpegurl")
                    //let analytics = ()
                    
                    var ads: [AdDescription] = []
                    if self.adUrl != nil {
                        let ad = GoogleImaAdDescription(src: self.adUrl!)
                        ads.append(ad)
                    }
                    let source = SourceDescription(source: typedSource, ads: ads, poster: splashLink/*, analytics: [analytics]*/)
                    self.theoplayer.source = source
                }
            }
        }
    }
    
    private func makeGetCall(endpoint: String, onCompletion: @escaping ([String : Any]) -> ()) {
        // Set up the URL request
        guard let url = URL(string: endpoint) else {
            print("Error: cannot create URL")
            return
        }
        let urlRequest = URLRequest(url: url)
        
        // set up the session
        let config = URLSessionConfiguration.default
        let session = URLSession(configuration: config)
        
        // make the request
        let task = session.dataTask(with: urlRequest) {
            (data, response, error) in
            // check for any errors
            guard error == nil else {
                print("error calling GET on " + endpoint)
                print(error!)
                return
            }
            // make sure we got data
            guard let responseData = data else {
                print("Error: did not receive data")
                return
            }
            // parse the result as JSON, since that's what the API provides
            do {
                guard let parsedJson: [String : Any] = try JSONSerialization.jsonObject(with: responseData, options: [])
                    as? [String: Any] else {
                        print("error trying to convert data to JSON")
                        return
                }
                onCompletion(parsedJson)

            } catch  {
                print("error trying to convert data to JSON")
                return
            }
        }
        task.resume()
    }
    
    
}
