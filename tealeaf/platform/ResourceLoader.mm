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

#include <sys/stat.h>
#include <string.h>
#import "ResourceLoader.h"
#import "Base64.h"
#import "TeaLeafAppDelegate.h"
#include "text_manager.h"
#include "texture_manager.h"
#include "events.h"
#include "log.h"
#include "core/core.h"
#include "core/image_loader.h"
#include "core/config.h"
#include "core/util/detect.h"


#define APP @"app.bundle"

#define MAX_HALFSIZE_SKIP 64

static ResourceLoader *instance = nil;
static NSThread *imgThread = nil;
static const char *base_path = 0;

@interface ResourceLoader ()
@property (nonatomic, assign) TeaLeafAppDelegate *appDelegate;
@end


@interface RawImageInfo : NSObject
@property(nonatomic,retain) NSString *url;
@property(nonatomic) unsigned char *raw_data;
@property(nonatomic) int w;
@property(nonatomic) int h;
@property(nonatomic) int ow;
@property(nonatomic) int oh;
@property(nonatomic) int scale;
@property(nonatomic) int channels;
- (id) initWithData:(unsigned char*)raw_data andURL:(NSString *)url andW:(int)w andH:(int)h andOW:(int)ow andOH:(int)oh andScale:(int)scale andChannels:(int)channels;
@end

@implementation RawImageInfo
- (void) dealloc {
	self.url = nil;

	[super dealloc];
}

- (id) initWithData:(unsigned char*)raw_data andURL:(NSString *)url andW:(int)w andH:(int)h andOW:(int)ow andOH:(int)oh andScale:(int)scale andChannels:(int)channels {
	if ((self = [super init])) {
		self.url = url;
		self.raw_data = raw_data;
		self.w = w;
		self.h = h;
		self.ow = ow;
		self.oh = oh;
		self.scale = scale;
		self.channels = channels;
	}
	return self;
}
@end


@interface ImageInfo : NSObject
@property(retain) NSString *url;
@property(retain) UIImage *image;
- (id) initWithImage: (UIImage *)image andUrl:(NSString *)url;
@end


@implementation ImageInfo
- (void) dealloc {
	self.url = nil;
	self.image = nil;
	
	[super dealloc];
}

- (id) initWithImage: (UIImage *)image andUrl:(NSString *)url {
	if((self = [super init])) {
		self.url = url;
		self.image = image;
	}
	return self;
}

@end


@implementation ResourceLoader

+ (void) release {
	
	if (instance != nil) {
		[instance  release];
		instance = nil;
	}
}

+ (ResourceLoader *) get {
	if (instance == nil) {
		instance = [[ResourceLoader alloc] init];
		imgThread = [[NSThread alloc] initWithTarget:instance selector:@selector(imageThread) object:nil];
		instance.appDelegate = ((TeaLeafAppDelegate *)[[UIApplication sharedApplication] delegate]);
		[imgThread start];
		LOG("creating resourceloader");
	}
	return [instance retain];
}

- (void) dealloc {
	self.appBundle = nil;
	self.images = nil;
	self.imageWaiter = nil;
	self.baseURL = nil;
	[imgThread release];
	[super dealloc];
}

- (id) init {
	self = [super init];

	self.appBundle = [[NSBundle mainBundle] pathForResource:@"resources" ofType:@"bundle"];
	self.images = [[[NSMutableArray alloc] init] autorelease];
	self.imageWaiter = [[[NSCondition alloc] init] autorelease];

	return self;
}

- (NSString *) initStringWithContentsOfURL:(NSString *)url {
	//check config for test app
	
	bool isRemoteLoading = [[self.appDelegate.config objectForKey:@"remote_loading"] boolValue];
	NSString *urlFormat = nil;
	if (!isRemoteLoading) {
		urlFormat = @"%@";
	} else {
		urlFormat = @"file://%@";
	}

	NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:[NSString stringWithFormat:urlFormat, [self resolve: url]]] cachePolicy:0 timeoutInterval:600];
	NSURLResponse *response = nil;
	NSError *error = nil;
	NSData *data = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
	if (data == nil) {
		NSLOG(@"{resources} FAILED: Unable to read '%@' : %@", url, [error localizedFailureReason]);
		return nil;
	} else {
		
		NSString *result = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];

		if (NSOrderedSame == [result compare:@"Cannot GET" options:NSLiteralSearch range:NSMakeRange(0, 10)]) {
			[result release];
			return nil;
		} else {
			return result;
		}
	}
}

- (NSURL*) resolve:(NSString *)url {
	if([url hasPrefix: @"http"] || [url hasPrefix: @"data"]) {
		return [NSURL URLWithString: url];
	}
	if (!config_get_remote_loading()) {
		return [self resolveFile: url];
	} else {
		return [self resolveFileUrl: url];
	}
}

- (NSURL*) resolveFile:(NSString*) path {
	return [NSURL fileURLWithPath:[NSString stringWithFormat:@"%@/%@", self.appBundle, path]];
}

- (NSURL*) resolveUrl: (NSString*) url {
	url = [NSString stringWithFormat:@"code/__cmd__/%@", url];
	return [NSURL URLWithString: [NSString stringWithFormat:@"http://%s:%d/%@", config_get_code_host(), config_get_code_port(), url]];
}

- (NSURL *) resolveFileUrl:(NSString *)url {
	return [NSURL URLWithString:[NSString stringWithFormat:@"file://%@/%@", [[instance.appDelegate.config objectForKey:@"app_files_dir"] stringByReplacingOccurrencesOfString:@" " withString:@"%20"], url ]];
	//return url to file on disk
}

- (void) imageThread {
	NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
	while(true) {
		//continue;
		[self.imageWaiter lock];
		[self.imageWaiter wait];
		NSArray* imgs = [NSArray arrayWithArray: self.images];
		[self.images removeAllObjects];
		[self.imageWaiter unlock];
		do {
			for (NSUInteger i = 0, count = [imgs count]; i < count; i++) {
				NSString* url = [imgs objectAtIndex:i];
				NSLOG(@"{resources} Loading url:%@", url);
				if([url hasPrefix: @"@TEXT"]) {
					[self performSelectorOnMainThread: @selector(finishLoadingText:) withObject: url waitUntilDone:NO];
				} else if([url hasPrefix: @"@CONTACTPICTURE"]) {
					// TODO Contact pictures again...
				} else if([url hasPrefix: @"MULTICONTACTPICTURES"]) {
					// TODO sprite contact pictures...
					NSLOG(@"{resources} ERROR: Contact pictures not supported yet!");
				} else if([url hasPrefix: @"CAMERA"]) {
					// do nothing for now
					NSLOG(@"{resources} ERROR: Camera not supported yet!");
				} else if([url hasPrefix: @"GALLERYPHOTO"]) {
					// do nothing for now
					NSLOG(@"{resources} ERROR: Gallery photo picking not supported yet!");
				} else {
					// it's a plain url
					NSData* data = nil;
					if([url hasPrefix: @"data:"]) {
						NSRange range = [url rangeOfString:@","];
						NSString* str = [url substringFromIndex: range.location+1];
						data = decodeBase64(str);
					} else {
						data = [NSData dataWithContentsOfURL: [self resolve: url]];
					}

					unsigned char *tex_data = NULL;
					int ch, w, h, ow, oh, scale;
					unsigned int raw_length = [data length];
					if (raw_length > 0) {
						const void *raw_data = [data bytes];

						if (raw_data) {
							tex_data = texture_2d_load_texture_raw([url UTF8String], raw_data, raw_length, &ch, &w, &h, &ow, &oh, &scale);
						}
					}

					if(tex_data) {
						RawImageInfo* info = [[RawImageInfo alloc] initWithData:tex_data andURL:url andW:w andH:h andOW:ow andOH:oh andScale:scale andChannels:ch];
						[self performSelectorOnMainThread:@selector(finishLoadingRawImage:) withObject:info waitUntilDone:NO];
					} else {
						LOG("{resources} WARNING: 404 %s", [url UTF8String]);
						[self performSelectorOnMainThread:@selector(failedLoadImage:) withObject: url waitUntilDone:NO];
					}
				}
			}
			imgs = [NSArray arrayWithArray: self.images];
			[self.images removeAllObjects];
		} while([imgs count] > 0);
	}

	[pool release];
}

- (UIImage *) normalize: (UIImage *) src {
	
	CGSize size = CGSizeMake(round(src.size.width), round(src.size.height));
	CGColorSpaceRef genericColorSpace = CGColorSpaceCreateDeviceRGB();
	CGContextRef thumbBitmapCtxt = CGBitmapContextCreate(NULL,
														 size.width,
														 size.height,
														 8, (4 * size.width),
														 genericColorSpace,
														 kCGImageAlphaPremultipliedFirst);
	CGColorSpaceRelease(genericColorSpace);
	CGContextSetInterpolationQuality(thumbBitmapCtxt, kCGInterpolationDefault);
	CGRect destRect = CGRectMake(0, 0, size.width, size.height);
	CGContextDrawImage(thumbBitmapCtxt, destRect, src.CGImage);
	CGImageRef tmpThumbImage = CGBitmapContextCreateImage(thumbBitmapCtxt);
	CGContextRelease(thumbBitmapCtxt);
	UIImage *result = [UIImage imageWithCGImage:tmpThumbImage scale:1.0 orientation:UIImageOrientationUp];
	CGImageRelease(tmpThumbImage);
	
	return result;
}

- (void) loadImage:(NSString *)url {
	if([url hasPrefix: @"@TEXT"]) {
		[self performSelectorOnMainThread: @selector(finishLoadingText:) withObject: url waitUntilDone:NO];
	} else if (url) {
		[self.images addObject: url];
		[self.imageWaiter broadcast];
	}
}

- (void) failedLoadImage: (NSString*) url {
	texture_manager_on_texture_failed_to_load(texture_manager_get(), [url UTF8String]);
	NSString* evt = [NSString stringWithFormat:@"{\"name\":\"imageError\",\"url\":\"%@\"}", url];
	core_dispatch_event([evt UTF8String]);
}

- (void) finishLoadingText: (NSString *) url {
	// Format: @TEXT<font>|<pt size>|<red>|<green>|<blue>|<alpha>|<max width>|<text style>|<stroke width>|<text>
	NSArray* parts = [[url substringFromIndex:5] componentsSeparatedByString: @"|"];

	// If text string is formatted properly,
	if (parts && [parts count] >= 10) {
		NSString *family = [parts objectAtIndex: 0],
		*str = [parts objectAtIndex: 9];
		CGFloat size = [[parts objectAtIndex: 1] floatValue];
		GLfloat colorf[] = {
			[[parts objectAtIndex: 2] floatValue] / 255.f,
			[[parts objectAtIndex: 3] floatValue] / 255.f,
			[[parts objectAtIndex: 4] floatValue] / 255.f,
			[[parts objectAtIndex: 5] floatValue] / 255.f
		};
		GLint maxWidth = [[parts objectAtIndex:6] intValue];
		GLint textStyle = [[parts objectAtIndex:7] intValue];
		GLfloat strokeWidth = [[parts objectAtIndex:8] intValue] / 4.f;
		
		Texture2D *tex = [[[Texture2D alloc] initWithString:str fontName:family fontSize:size color:colorf maxWidth:maxWidth textStyle:textStyle strokeWidth:strokeWidth] autorelease];

		if (tex) {
			texture_manager_on_texture_loaded(texture_manager_get(), [url UTF8String], tex.name, tex.width, tex.height, tex.originalWidth, tex.originalHeight, 4, 1, true);
			
			NSLOG(@"{resources} Loaded text %@ id:%d (%d,%d)->(%u,%u)", url, tex.name, tex.originalWidth, tex.originalHeight, tex.width, tex.height);
		}
	}
}

- (void) finishLoadingImage:(ImageInfo *)info {
	Texture2D* tex = [[Texture2D alloc] initWithImage:info.image andUrl: info.url];
	int scale = use_halfsized_textures ? 2 : 1;
	texture_manager_on_texture_loaded(texture_manager_get(), [tex.src UTF8String], tex.name, tex.width * scale, tex.height * scale, tex.originalWidth * scale, tex.originalHeight * scale, 4, scale, false);
	NSString* evt = [NSString stringWithFormat: @"{\"name\":\"imageLoaded\",\"url\":\"%@\",\"glName\":%d,\"width\":%d,\"height\":%d,\"originalWidth\":%d,\"originalHeight\":%d}",
					 tex.src, tex.name, tex.width, tex.height, tex.originalWidth, tex.originalHeight];
	core_dispatch_event([evt UTF8String]);
	NSLOG(@"{resources} Loaded image %@ id:%d (%d,%d)->(%u,%u)", tex.src, tex.name, tex.originalWidth, tex.originalHeight, tex.width, tex.height);

	[info release];
	[tex release];
}

- (void) finishLoadingRawImage:(RawImageInfo *)info {
	GLuint texture = 0;
	glGenTextures(1, &texture);
	glBindTexture(GL_TEXTURE_2D, texture);
	glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
	glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
	glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);
	glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);

	const char *url = [info.url UTF8String];

	//create the texture
	int shift = info.scale - 1;
	glTexImage2D(GL_TEXTURE_2D, 0, info.channels == 4 ? GL_RGBA : GL_RGB, info.w >> shift, info.h >> shift, 0, info.channels == 4 ? GL_RGBA : GL_RGB, GL_UNSIGNED_BYTE, info.raw_data);
	core_check_gl_error();

	texture_manager_on_texture_loaded(texture_manager_get(), url, texture,
									  info.w, info.h, info.ow, info.oh,
									  info.channels, info.scale, false);

	//create json event string
	char buf[512];
	snprintf(buf, sizeof(buf),
			 "{\"url\":\"%s\",\"height\":%d,\"originalHeight\":%d,\"originalWidth\":%d" \
			 ",\"glName\":%d,\"width\":%d,\"name\":\"imageLoaded\",\"priority\":0}",
			 url, (int)info.h,
			 (int)info.oh, (int)info.ow,
			 (int)texture, (int)info.w);

	core_dispatch_event(buf);

	[info release];
}

@end


static unsigned char *read_file(const char *url, unsigned long *sz) {
	unsigned char *data = NULL;
	/* check if the image resides on the file system first */
	if (!url || strlen(url) == 0) {
		return NULL;
	}
	int len = strlen(base_path) + strlen(url) + 1 +1; //adding the slash
	char * path = (char*)malloc(len);
	memset(path, 0, len);
	
	sprintf(path, "%s/%s", base_path, url);
	
	struct stat statBuf;
	int result = stat(path, &statBuf);
	// try the file system first
	bool on_file_sys = (result != -1);
	if(on_file_sys && statBuf.st_size > 0) {
		FILE * file_from_sys = fopen(path, "r");
		
		if(!file_from_sys) {
			on_file_sys = false;
		} else {
			*sz = statBuf.st_size;
			data = (unsigned char*)malloc(*sz);
			memset(data, 0, *sz);
			fread(data, sizeof(unsigned char), *sz, file_from_sys);
			fclose(file_from_sys);
		}
	}	 
	free(path);
	return data;
}

CEXPORT bool resource_loader_load_image_with_c(texture_2d *texture) {
	unsigned long sz = 0;
	unsigned char *data = read_file(texture->url, &sz);

	if (!data) {
		texture->pixel_data = NULL;

		return false;
	} else {
		texture->pixel_data = texture_2d_load_texture_raw(texture->url, data, sz, &texture->num_channels, &texture->width, &texture->height, &texture->originalWidth, &texture->originalHeight, &texture->scale);

		free(data);
		return true;
	}
}

CEXPORT const char* resource_loader_string_from_url(const char* url) {
	ResourceLoader* loader = [ResourceLoader get];
	NSString* nsurl = [NSString stringWithUTF8String:url];
	NSString* contents = [[loader initStringWithContentsOfURL: nsurl] autorelease];
	const char *contents_str = [contents UTF8String];
	if (contents_str) {
		contents_str = strdup(contents_str);
	}
	return contents_str;
}

CEXPORT void resource_loader_initialize(const char *path) {
	base_path = strdup(path);
}

CEXPORT void resource_loader_load_image(const char* url) {
	LOG("{resources} Queuing %s", url);
	[[ResourceLoader get] loadImage: [NSString stringWithUTF8String: url]];
}

CEXPORT void launch_remote_texture_load(const char *url) {
	resource_loader_load_image(url);
}
