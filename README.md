
GSTwitPicEngine
===============

GSTwitPicEngine provides easy to implement wrapper around the TwitPic.com's OAuth (v1) and OAuth Echo (v2) API for iPhone application projects.

Requirements
------------

 * **ASIHTTPRequest** - http://allseeing-i.com/ASIHTTPRequest/
 * **OAuthConsumer** - http://github.com/jdg/oauthconsumer
 * **OARequestHeader** - http://github.com/Gurpartap/OARequestHeader
 * One of these **JSON parsers**:
   - yajl & yajl-objc (enabled by default) - http://github.com/gabriel/yajl-objc
   - TouchJSON
   - SBJSON
 * MGTwitterEngine or anything of your choice that supplies the **OAToken instance** (from OAuthConsumer).

Usage
-----

 * Set kTwitterOAuthConsumerKey, kTwitterOAuthConsumerSecret and kTwitPicAPIKey constants to their respective values before GSTwitPicEngine.h is imported.
 * See GSTwitPicEngine.h to configure TwitPic API Format (XML or JSON) and to set which JSON Parser to use.
 * Add header file:

        #import "GSTwitPicEngine.h"
 * Setup retained (@synthesize) instance var/property in the header:

        GSTwitPicEngine *twitpicEngine;
 * Implement **GSTwitPicEngineDelegate** protocol for the class.
 * Initialize the engine with class or as needed:

        self.twitpicEngine = (GSTwitPicEngine *)[GSTwitPicEngine twitpicEngineWithDelegate:self];
 * Find the authorization token and supply to twitpicEngine with:

        [twitpicEngine setAccessToken:token];
 * Then to upload image and attach a text message along with it (does not post to twitter):

        [twitpicEngine uploadPicture:[UIImage imageNamed:@"mypic.png"]  withMessage:@"Hello world!"]; // This message is supplied back in success delegate call in request's userInfo.
 * To upload image only:

        [twitpicEngine uploadPicture:uploadImageView.image];
* Upon end of request, one of the delegate methods is called with appropriate data and information.

GSTwitPicEngineDelegate
-----------------------

 * GSTwitPicEngineDelegate protocol specifies two delegate methods:

<pre>- (void)twitpicDidFinishUpload:(NSDictionary *)response {
  NSLog(@"TwitPic finished uploading: %@", response);

  // [response objectForKey:@"parsedResponse"] gives an NSDictionary of the response one of the parsing libraries was available.
  // Otherwise, use [[response objectForKey:@"request"] objectForKey:@"responseString"] to parse yourself.

  if ([[[response objectForKey:@"request"] userInfo] objectForKey:@"message"] > 0 && [[response objectForKey:@"parsedResponse"] count] > 0) {
    // Uncomment to update status upon successful upload, using MGTwitterEngine's instance.
    // [twitterEngine sendUpdate:[NSString stringWithFormat:@"%@ %@", [[[response objectForKey:@"request"] userInfo] objectForKey:@"message"], [[response objectForKey:@"parsedResponse"] objectForKey:@"url"]]];
  }
}</pre>

<pre>- (void)twitpicDidFailUpload:(NSDictionary *)error {
  NSLog(@"TwitPic failed to upload: %@", error);
  
  if ([[error objectForKey:@"request"] responseStatusCode] == 401) {
    // UIAlertViewQuick(@"Authentication failed", [error objectForKey:@"errorDescription"], @"OK");
  }
}
</pre>

Contact
-------

Find me on Twitter: http://twitter.com/Gurpartap
Or use the form at http://gurpartap.com/contact to talk privately (ooooh!!).

License
-------

Copyright (c) 2010 Gurpartap Singh, http://gurpartap.com/

This code is licensed under the MIT License

You are free:

 * to Share — to copy, distribute and transmit the work
 * to Remix — to adapt the work

Under the following conditions:

 * The copyright notice and license shall be included in all copies or substantial portions of the software.
 * Any of the above conditions can be waived if you get permission from the copyright holder.

See bundled MIT-LICENSE.txt file for detailed license terms.