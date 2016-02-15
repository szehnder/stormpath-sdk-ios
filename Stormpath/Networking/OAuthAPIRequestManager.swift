//
//  OAuthAPIRequestManager.swift
//  Stormpath
//
//  Created by Edward Jiang on 2/5/16.
//  Copyright © 2016 Stormpath. All rights reserved.
//

import Foundation

typealias OAuthAPIRequestCallback = ((String?, refreshToken: String?, NSError?) -> Void)

class OAuthAPIRequestManager: APIRequestManager {
    var requestBody: String
    var callback: OAuthAPIRequestCallback
    
    private init(withURL url: NSURL, requestBody: String, callback: OAuthAPIRequestCallback) {
        self.requestBody = requestBody
        self.callback = callback
        
        super.init(withURL: url)
    }
    
    convenience init(withURL url: NSURL, username: String, password: String, callback: OAuthAPIRequestCallback) {
        let requestBody = "username=\(username.formURLEncoded)&password=\(password.formURLEncoded)&grant_type=password"
        
        self.init(withURL: url, requestBody: requestBody, callback: callback)
    }
    
    convenience init(withURL url: NSURL, refreshToken: String, callback: OAuthAPIRequestCallback) {
        let requestBody = String(format: "refresh_token=%@&grant_type=refresh_token", refreshToken)
        
        self.init(withURL: url, requestBody: requestBody, callback: callback)
    }
    
    override func prepareForRequest() {
        request.HTTPMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.HTTPBody = requestBody.dataUsingEncoding(NSUTF8StringEncoding)
    }
    
    override func requestDidFinish(data: NSData, response: NSHTTPURLResponse) {
        guard let json = (try? NSJSONSerialization.JSONObjectWithData(data, options: [])) as? NSDictionary,
            accessToken = json["access_token"] as? String else {
            //Callback and return
            executeCallback(nil, error: StormpathError.APIResponseError)
            return
        }
        let refreshToken = json["refresh_token"] as? String
        
        executeCallback(accessToken, refreshToken: refreshToken, error: nil)
    }
    
    override func executeCallback(parameters: AnyObject?, error: NSError?) {
        executeCallback(nil, refreshToken: nil, error: error)
    }
    
    func executeCallback(accessToken: String?, refreshToken: String?, error: NSError?) {
        dispatch_async(dispatch_get_main_queue()) { 
            self.callback(accessToken, refreshToken: refreshToken, error)
        }
    }
}


// There's an argument to be made for this to be a string category, but since this is the only method and only needed for this class...

// Custom URL encode, 'cos iOS is missing one. This one is blatantly stolen from AFNetworking's implementation of percent escaping and converted to Swift

private extension String {
    var formURLEncoded: String {
        let charactersGeneralDelimitersToEncode = ":#[]@"
        let charactersSubDelimitersToEncode     = "!$&'()*+,;="
        
        let allowedCharacterSet: NSMutableCharacterSet = NSCharacterSet.URLHostAllowedCharacterSet().mutableCopy() as! NSMutableCharacterSet
        
        allowedCharacterSet.removeCharactersInString(charactersGeneralDelimitersToEncode.stringByAppendingString(charactersSubDelimitersToEncode))
        
        return self.stringByAddingPercentEncodingWithAllowedCharacters(allowedCharacterSet)!
    }
}