//
//  GSTwitPicEngine.m
//  TwitPic Uploader
//
//  Created by Gurpartap Singh on 19/06/10.
//  Copyright 2010 Gurpartap Singh. All rights reserved.
//

#import "GSTwitPicEngine.h"

#if TWITPIC_USE_YAJL
#import "NSObject+YAJL.h"

#elif TWITPIC_USE_SBJSON
#import "JSON.h"

#elif TWITPIC_USE_TOUCHJSON
#import "CJSONDeserializer.h"

//  #elif TWITPIC_USE_LIBXML
//    #include <libxml/xmlreader.h>
#endif

#import "ASIFormDataRequest.h"
#import "ASINetworkQueue.h"

#import "OAConsumer.h"
#import "OARequestHeader.h"

@implementation GSTwitPicEngine

@synthesize _queue;

+ (GSTwitPicEngine *)twitpicEngineWithDelegate:(NSObject *)theDelegate {
  return [[[self alloc] initWithDelegate:theDelegate] autorelease];
}


- (GSTwitPicEngine *)initWithDelegate:(NSObject *)delegate {
  if (self = [super init]) {
    _delegate = delegate;
    _queue = [[ASINetworkQueue alloc] init];
    [_queue setMaxConcurrentOperationCount:1];
    [_queue setShouldCancelAllRequestsOnFailure:NO];
    [_queue setDelegate:self];
    [_queue setRequestDidFinishSelector:@selector(requestFinished:)];
    [_queue setRequestDidFailSelector:@selector(requestFailed:)];
    // [_queue setQueueDidFinishSelector:@selector(queueFinished:)];
  }
  
  return self;
}


- (void)dealloc {
  _delegate = nil;
  [_queue release];
  [super dealloc];
}


#pragma mark -
#pragma mark Instance methods

- (BOOL)_isValidDelegateForSelector:(SEL)selector {
	return ((_delegate != nil) && [_delegate respondsToSelector:selector]);
}


- (void)uploadPicture:(UIImage *)picture {
  [self uploadPicture:picture withMessage:@""];
}


- (void)uploadPicture:(UIImage *)picture withMessage:(NSString *)message {
  if ([TWITPIC_API_VERSION isEqualToString:@"1"]) {
    // TwitPic OAuth.
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://api.twitpic.com/1/upload.%@", TWITPIC_API_FORMAT]];
    
    ASIFormDataRequest *request = [ASIFormDataRequest requestWithURL:url];
    
    [request addPostValue:TWITPIC_API_KEY forKey:@"key"];
    [request addPostValue:TWITTER_OAUTH_CONSUMER_KEY forKey:@"consumer_token"];
    [request addPostValue:TWITTER_OAUTH_CONSUMER_SECRET forKey:@"consumer_secret"];
    [request addPostValue:[_accessToken key] forKey:@"oauth_token"];
    [request addPostValue:[_accessToken secret] forKey:@"oauth_secret"];
    [request addPostValue:message forKey:@"message"];
    [request addData:UIImageJPEGRepresentation(picture, 0.8) forKey:@"media"];
    
    request.requestMethod = @"POST";
    
    [_queue addOperation:request];
    [_queue go];
  }
  else {
    // Twitter OAuth Echo.
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://api.twitpic.com/2/upload.%@", TWITPIC_API_FORMAT]];
    
    OAConsumer *consumer = [[[OAConsumer alloc] initWithKey:TWITTER_OAUTH_CONSUMER_KEY secret:TWITTER_OAUTH_CONSUMER_SECRET] autorelease];
    
    // NSLog(@"consumer: %@", consumer);
    
    OARequestHeader *requestHeader = [[[OARequestHeader alloc] initWithProvider:@"https://api.twitter.com/1/account/verify_credentials.json"
                                                                         method:@"GET"
                                                                       consumer:consumer
                                                                          token:_accessToken
                                                                          realm:@"http://api.twitter.com/"] autorelease];
    
    NSString *oauthHeaders = [requestHeader generateRequestHeaders];
    
    ASIFormDataRequest *request = [ASIFormDataRequest requestWithURL:url];
    [request setUserInfo:[NSDictionary dictionaryWithObject:message forKey:@"message"]];
    
    [request addRequestHeader:@"X-Verify-Credentials-Authorization" value:oauthHeaders];
    [request addRequestHeader:@"X-Auth-Service-Provider" value:@"https://api.twitter.com/1/account/verify_credentials.json"];
    
    [request addPostValue:TWITPIC_API_KEY forKey:@"key"];
    [request addPostValue:message forKey:@"message"];
    [request addData:UIImageJPEGRepresentation(picture, 0.8) forKey:@"media"];
    
    request.requestMethod = @"POST";
    
    // NSLog(@"requestHeaders: %@", [request requestHeaders]);
    
    [_queue addOperation:request];
    [_queue go];
  }
}


#pragma mark -
#pragma mark OAuth

- (void)setAccessToken:(OAToken *)token {
	[_accessToken autorelease];
	_accessToken = [token retain];
}


#pragma mark -
#pragma mark ASIHTTPRequestDelegate methods

- (void)requestFinished:(ASIHTTPRequest *)request {
  // TODO: Pass values as individual parameters to delegate methods instead of wrapping in NSDictionary.
  NSMutableDictionary *delegateResponse = [[[NSMutableDictionary alloc] init] autorelease];
  
  [delegateResponse setObject:request forKey:@"request"];
  
  switch ([request responseStatusCode]) {
    case 200:
    {
      // Success, but let's parse and see.
      // TODO: Error out if parse failed?
      // TODO: Need further checks for success.
      NSDictionary *response = [[NSDictionary alloc] init];
      NSString *responseString = nil;
      responseString = [request responseString];
      
      @try {
#if TWITPIC_USE_YAJL
        response = [responseString yajl_JSON];
#elif TWITPIC_USE_SBJSON
        response = [responseString JSONValue];
#elif TWITPIC_USE_TOUCHJSON
        NSError *error = nil;
        response = [[CJSONDeserializer deserializer] deserialize:responseString error:&error];
        if (error != nil) {
          @throw([NSException exceptionWithName:@"TOUCHJSONParsingException" reason:[error localizedFailureReason] userInfo:[error userInfo]]);
        }
// TODO: Implemented XML Parsing.
// #elif TWITPIC_USE_LIBXML
#endif
      }
      @catch (NSException *e) {
        NSLog(@"Error while parsing TwitPic response. Does the project really have the parsing library specified? %@.", e);
        return;
      }
      
      [delegateResponse setObject:response forKey:@"parsedResponse"];
      
      if ([self _isValidDelegateForSelector:@selector(twitpicDidFinishUpload:)]) {
        [_delegate twitpicDidFinishUpload:delegateResponse];
      }
      
      break;
    }
    case 400:
      // Failed.
      [delegateResponse setObject:@"Bad request. Missing parameters." forKey:@"errorDescription"];
      
      if ([self _isValidDelegateForSelector:@selector(twitpicDidFailUpload:)]) {
        [_delegate twitpicDidFailUpload:delegateResponse];
      }
      
      break;
    default:
      [delegateResponse setObject:@"Request failed." forKey:@"errorDescription"];
      
      if ([self _isValidDelegateForSelector:@selector(twitpicDidFailUpload:)]) {
        [_delegate twitpicDidFailUpload:delegateResponse];
      }
      
      break;
  }
}


- (void)requestFailed:(ASIHTTPRequest *)request {
  NSMutableDictionary *delegateResponse = [[[NSMutableDictionary alloc] init] autorelease];
  
  [delegateResponse setObject:request forKey:@"request"];
  
  switch ([request responseStatusCode]) {
    case 401:
      // Twitter.com could be down or slow. Or your request took too long to reach twitter.com authentication verification via twitpic.com.
      // TODO: Attempt to try again?
      [delegateResponse setObject:@"Timed out verifying authentication token with Twitter.com. This could be a problem with TwitPic servers. Try again later." forKey:@"errorDescription"];
      
      break;
    default:
      [delegateResponse setObject:@"Request failed." forKey:@"errorDescription"];
      break;
  }
  
	if ([self _isValidDelegateForSelector:@selector(twitpicDidFailUpload:)]) {
		[_delegate twitpicDidFailUpload:delegateResponse];
  }
}


@end
