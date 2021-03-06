/* @license
 * This file is part of the Game Closure SDK.
 *
 * The Game Closure SDK is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 
 * The Game Closure SDK is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 
 * You should have received a copy of the GNU General Public License
 * along with the Game Closure SDK.	 If not, see <http://www.gnu.org/licenses/>.
 */

#import "xhr.h"
#import "JS.h"
#import "jsXHR.h"

@implementation XHR

-(void) dealloc {
	self.data = nil;
	self.headers = nil;
	self.connection = nil;

	[super dealloc];
}

-(id)initWithURL:(NSURL*)url andMethod:(NSString*)method andBody:(NSString*)body andHeaders:(NSDictionary*)hdrs andID:(int)theId {

	self = [super init];

	NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
	[req setHTTPMethod:[method uppercaseString]];
	[req setHTTPBody:[body dataUsingEncoding:NSUTF8StringEncoding]];

	if (hdrs) {
		for (NSString *key in hdrs) {
			NSString *value = [hdrs valueForKey:key];

			[req setValue:value forHTTPHeaderField:key];
		}
	}

	self.connection = [[[NSURLConnection alloc] initWithRequest:req delegate:self startImmediately:YES] autorelease];
	self.state = 4;
	self.myID = theId;

	return self;
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
	self.data = [NSMutableData data];
	self.headers = [(NSHTTPURLResponse*)response allHeaderFields];
	self.status = [(NSHTTPURLResponse*)response statusCode];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)d {
	[self.data appendData:d];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
}

- (void)connectionDidFinishLoading:(NSURLConnection *)conn {
	NSString *responseText = [[[NSString alloc] initWithData:self.data encoding:NSUTF8StringEncoding] autorelease];

	[jsXHR onResponse:responseText fromRequest: self];

	self.connection = nil;
}

+ (XHR *) httpRequestForURL:(NSURL*)url withMethod:(NSString*)method andBody:(NSString*)body andHeaders:(NSDictionary*)hdrs andID:(int)theId
{
	return [[[XHR alloc] initWithURL:url andMethod:method andBody:body andHeaders:hdrs andID:theId] autorelease];
}

@end
