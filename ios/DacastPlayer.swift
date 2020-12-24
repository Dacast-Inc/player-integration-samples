import Foundation
import THEOplayerSDK

class ContentId{
    var provider: String = ""
    var infoUrl: String = ""
    var tokenUrl: String = ""
    var broadcasterId: Int = 0
    var mediaId: Int = 0
    var mediaString: String = ""
    var contentType: String = ""
    var userId: String = ""
    var contentId: String = ""
}

class DacastContentId: ContentId{
    init(contentIdStr: String) {
        super.init()
        let split = contentIdStr.split(separator: "_")
        
        self.broadcasterId = Int(split[0])!
        self.mediaId = Int(split[2])!
        self.contentType = String(split[1])
        self.provider = "dacast"
        self.infoUrl = "https://json.dacast.com/b/" + String(self.broadcasterId) + "/" + self.contentType + "/" + String(self.mediaId)
        self.tokenUrl = "https://services.dacast.com/token/i/b/" + String(self.broadcasterId) + "/" + self.contentType + "/" + String(self.mediaId) 
    }
}

class UniverseContentId: ContentId{
    init(contentIdStr: String) {
        super.init()
        //contentIdStr: 486dee4e-63b8-b2dc-3de3-5e6290a08281-vod-486dee4e-63b8-b2dc-3de3-5e6290a08281
        self.contentId = contentIdStr
        let split = contentIdStr.split(separator: "-")
        self.userId = [String(split[0]), String(split[1]), String(split[2]), String(split[3]), String(split[4])].joined(separator: "-")
        self.contentType = String(split[5])
        self.mediaString = [String(split[6]), String(split[7]), String(split[8]), String(split[9]), String(split[10])].joined(separator: "-")
        self.provider = "universe"
        self.infoUrl = "https://playback.dacast.com/content/info?contentId="+contentId+"&provider=universe"
        self.tokenUrl = "https://playback.dacast.com/content/access?contentId="+contentId+"&provider=universe"
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
        
        view = UIView()
        
        let playerConfig = THEOplayerConfiguration(googleIMA: adUrl != nil)
        self.theoplayer = THEOplayer(configuration: playerConfig)
        theoplayer.insertAsSubview(of: view, at: 0)
                
        watermarkImg = UIImageView()
        watermarkImg.isOpaque = false
        watermarkImg.alpha = 0.3
        view.insertSubview(watermarkImg, at: 9990000)
        
        populatePlayerInfo(contentIdStr: contentIdStr)
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
    
    private func guessProviderFromContentId(contentId: String) -> String {
        if (contentId.firstIndex(of: "-") != nil) {
            return "universe"
        } else if (contentId.range(of: #"\d+_(f|c|l|p)_\d+"#, options: .regularExpression) != nil) {
            return "dacast"
        }
        else {
            return "null"
        }
    }
    
    private func toString(_ value: Any?) -> String {
      return String(describing: value ?? "")
    }
    
    private func populatePlayerInfo(contentIdStr: String){
        
        let contentProvider : String = guessProviderFromContentId(contentId: contentIdStr)
        
        var contentId: ContentId
        if (contentProvider == "universe") {
            contentId = UniverseContentId(contentIdStr: contentIdStr)
        }
        else if(contentProvider == "dacast") {
            contentId = DacastContentId(contentIdStr: contentIdStr)
        }
        else {
            print("Defaulting")
            contentId = ContentId()
        }
        
        print(contentId)
        
        makeGetCall(endpoint: contentId.infoUrl){
            jsonData in
            
            self.makeGetCall(endpoint: contentId.tokenUrl){
                serviceData in
                
                var splashLink: String
                var watermarkLink: Any?
                var textTracks: [TextTrackDescription] = []
                var m3u8Link: String
                
                if (contentId.provider == "dacast") {
                    m3u8Link = jsonData["hls"] as! String
                    m3u8Link += serviceData["token"] as! String
                    let streamData = jsonData["stream"] as! [String : Any]
                    splashLink = streamData["splash"] as! String
                    let themeData = jsonData["theme"] as! [String : Any]
                    let watermarkData = themeData["watermark"] as! [String : Any]
                    watermarkLink = watermarkData["url"]
                    let subTitles = jsonData["subtitles"]
                    
                    for subTitle in subTitles as! [Dictionary<String,AnyObject>]
                    {
                        let source = self.toString(subTitle["src"])
                        let language = self.toString(subTitle["language"])
                        let name = self.toString(subTitle["name"])
                        
                        let textTrack = TextTrackDescription(src: source, srclang: language, label: name)
                        textTracks.append(textTrack)
                    }
                }
                else {
                    m3u8Link = serviceData["hls"] as! String
                    let contentInfo = jsonData["contentInfo"] as! [String : Any]
                    splashLink = contentInfo["splashscreenUrl"] as! String
                    let featuresData = contentInfo["features"] as! [String : Any]
                    let watermarkData = featuresData["watermark"] as! [String : Any]
                    watermarkLink = watermarkData["imageUrl"]
                    
                    let subTitles = featuresData["subtitles"]
                    for subTitle in subTitles as! [Dictionary<String,AnyObject>]
                    {
                        let source = self.toString(subTitle["sourceVtt"])
                        let language = self.toString(subTitle["languageShortName"])
                        let name = self.toString(subTitle["languageLongName"])
                        
                        let textTrack = TextTrackDescription(src: source, srclang: language, label: name)
                        textTracks.append(textTrack)
                    }
                }
                
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
                    let source = SourceDescription(source: typedSource, ads: ads, textTracks: textTracks, poster: splashLink/*, analytics: [analytics]*/)
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
