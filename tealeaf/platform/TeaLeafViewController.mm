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

#import "TeaLeafViewController.h"
#import "jsMacros.h"
#import "js_core.h"
#import "core/log.h"
#import "TeaLeafAppDelegate.h"
#import "ResourceLoader.h"
#import "core/core.h"
#import "core/tealeaf_canvas.h"
#import "JSONKit.h"
#import "jansson.h"
#import "jsonUtil.h"
#import "allExtensions.h"
#include "platform.h"
#import "iosVersioning.h"
#include "core/core_js.h"
#include "core/texture_manager.h"

#include <sys/types.h>
#include <sys/sysctl.h>


// Get hw.machine
static NSString *get_platform() {
    size_t size;
    sysctlbyname("hw.machine", NULL, &size, NULL, 0);
    char *machine = (char*)malloc(size + 1);
    sysctlbyname("hw.machine", machine, &size, NULL, 0);
    machine[size] = '\0';
    NSString *platform = [NSString stringWithUTF8String:machine];
    free(machine);
    return platform;
}


@interface TeaLeafViewController ()
@property (nonatomic, assign) TeaLeafAppDelegate *appDelegate;
@end


@implementation TeaLeafViewController

- (TeaLeafViewController*) init {
	self = [super init];

	return self;
}

- (void) dealloc {
	[self.appDelegate.canvas destroyDisplayLink];
	[super dealloc];
}

- (void) alertView:(UIAlertView *)sheet clickedButtonAtIndex:(NSInteger)buttonIndex {
	NSString *title = [sheet buttonTitleAtIndex:buttonIndex];
	if ([title isEqualToString:@"Yes"]) {
		if (SYSTEM_VERSION_LESS_THAN(@"6.0")) {
			[self.view removeFromSuperview];
			
			[((TeaLeafAppDelegate*)[UIApplication sharedApplication].delegate).window addSubview:self.appDelegate.appTableViewController.view];
		} else {
			[((TeaLeafAppDelegate*)[UIApplication sharedApplication].delegate).window setRootViewController:self.appDelegate.appTableViewController ];
		}

		self.appDelegate.tealeafShowing = NO;

		if (js_ready) {
			dispatch_async(dispatch_get_main_queue(), ^{
				core_destroy();
			});
		}
	} else if ([title isEqualToString:@"No"]) {
		//do nothing
	} else {
		[(UIAlertViewEx*)sheet dispatch: buttonIndex];
		[sheet release];
	}
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation{
	if (isPortrait) {
		return (toInterfaceOrientation == UIInterfaceOrientationPortrait) ||
			   (toInterfaceOrientation == UIInterfaceOrientationPortraitUpsideDown);
	} else {
		return (toInterfaceOrientation == UIInterfaceOrientationLandscapeLeft) ||
			   (toInterfaceOrientation == UIInterfaceOrientationLandscapeRight);
	}
}

-(BOOL)shouldAutorotate {
	return YES;
}

- (NSUInteger)supportedInterfaceOrientations {
	if (isPortrait) {
		return UIInterfaceOrientationMaskPortrait | UIInterfaceOrientationMaskPortraitUpsideDown;
	} else {
		return UIInterfaceOrientationMaskLandscapeLeft | UIInterfaceOrientationMaskLandscapeRight;
		
	}
}

-(void) willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
	// CGRect bounds = [self.view bounds];
}

- (void)didReceiveMemoryWarning {
	// Releases the view if it doesn't have a superview.
	[super didReceiveMemoryWarning];
	
	// Release any cached data, images, etc that aren't in use.
}

static void ReadManifest(bool *isPortrait) {
	bool loaded_success = false;
	
	// TODO: Support changing orientation
	
	// Default: Fail to portrait mode
	*isPortrait = true;
	
	NSString *manifest_file = [[ResourceLoader get] initStringWithContentsOfURL:@"manifest.json"];
	if (manifest_file != nil) {
		const char *c_manifest_file = [manifest_file UTF8String];
		json_error_t err;
		json_t *manifest = json_loads(c_manifest_file, 0, &err);
		if (manifest && json_is_object(manifest)) {
			json_t *orient = json_object_get(manifest, "supportedOrientations");
			if (orient && json_is_array(orient)) {
				loaded_success = true;
				int orient_len = (int)json_array_size(orient);
				for (int ii = 0; ii < orient_len; ++ii) {
					json_t *entry = json_array_get(orient, ii);
					if (entry && json_is_string(entry)) {
						const char *str = json_string_value(entry);
						if (0 == strcasecmp(str, "landscape")) {
							// Landscape mode is specified
							*isPortrait = false;
						}
						else if (0 == strcasecmp(str, "portrait")) {
							// Portrait mode is specified
						}
					}
				}
			}
		}
		json_decref(manifest);
	} else {
		LOG("WARNING: Basil Server was not reachable or manifest.json not found");
	}
	
	if (!loaded_success) {
		LOG("ERROR: Unable to read manifest.json!!!");
	} else {
		LOG("Successfully read manifest.json");
	}
}


- (void)onJSReady {
	
	//This needs to be run on the main thread - it does some opengl stuff
	dispatch_async(dispatch_get_main_queue(), ^{
		// Launch!
		NSDictionary *json = @{
		@"appID" : fixDictString(self.appDelegate.config, @"app_id"),
		@"appleID" : fixDictString(self.appDelegate.config, @"apple_id"),
		@"bundleID" : fixDictString(self.appDelegate.config, @"bundle_id"),
		@"version" : fixDictString(self.appDelegate.config, @"version"),
		@"servicesURL" : fixDictString(self.appDelegate.config, @"services_url"),
		@"pushURL" : fixDictString(self.appDelegate.config, @"push_url"),
		@"contactsURL" : fixDictString(self.appDelegate.config, @"contacts_url"),
		@"userdataURL" : fixDictString(self.appDelegate.config, @"userdata_url"),
		@"studioName" : fixDictString(self.appDelegate.config, @"studio_name"),
		@"notification" : self.appDelegate.launchNotification?self.appDelegate.launchNotification:[NSNull null]
		};
		
		for (id key in json) {
			NSLOG(@"plugins init json: key=%@, value=%@", key, [json objectForKey:key]);
		}
		
		[self.appDelegate.pluginManager initializeUsingJSON:json];
		
		self.appDelegate.launchNotification = nil;
		
		// Initialize reachability notifications
		[self.appDelegate initializeOnlineState];
		
		core_run();
		
		[self.appDelegate postPauseEvent:self.appDelegate.wasPaused];
		
		// Start listening for changes to online state
		[self.appDelegate hookOnlineState];
	});

}

- (void)viewDidLoad {
	 self.appDelegate = ((TeaLeafAppDelegate *)[[UIApplication sharedApplication] delegate]);
	//TEALEAF_SPECIFIC_START
	/*
	 * based on reported width and height, calculate the width and
	 * height we care about with respect to scale (retina displays)
	 * and orientation (swapping width and height)
	 */
	
	 [[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];
	 UIDeviceOrientation orientation = [[UIDevice currentDevice] orientation];
	 
	 
	 CGRect frame = [self.appDelegate.window frame];
	 float scale = 1.0;
	 if ([UIScreen instancesRespondToSelector:@selector(scale)]) {
	 scale = [[UIScreen mainScreen] scale];
	 }
	 int w, h ;
	 
	 if (orientation == UIDeviceOrientationFaceUp || UIInterfaceOrientationIsPortrait(orientation)) {
		 w = frame.size.width;
		 h = frame.size.height;
	 } else {
		 w = frame.size.height;
		 h = frame.size.width;
	 }
	 w *= scale;
	 h *= scale;
	 
	
	 // Lookup source path
	
	 const char *source_path = [[ResourceLoader get].appBundle UTF8String];
	 if (!source_path || *source_path == '\0') {
		 source_path = [[self.appDelegate.config objectForKey:@"source_dir"] UTF8String];
	 }
	
	char *code_host = NULL;
#if TARGET_IPHONE_SIMULATOR
	code_host = "localhost";
#else
	code_host = (char*)[[self.appDelegate.config objectForKey:@"code_host"] UTF8String];
#endif
	
	 core_init([[self.appDelegate.config objectForKey:@"entry_point"] UTF8String],
	 [[self.appDelegate.config	objectForKey:@"tcp_host"] UTF8String],
	 [[self.appDelegate.config	objectForKey:@"code_host"] UTF8String],
	 [[self.appDelegate.config	objectForKey:@"tcp_port"] intValue],
	 [[self.appDelegate.config	objectForKey:@"code_port"] intValue],
	 source_path,
	 w,
	 h,
	 [[self.appDelegate.config objectForKey:@"remote_loading"] boolValue],
	 "");

    NSString *platform = get_platform();
    NSLog(@"{core} iOS device model '%@'", platform);

	// If iPad 1 or iPhone 3GS,
    if ([platform isEqualToString:@"iPad1,1"] ||
        [platform isEqualToString:@"iPhone2,1"]) {
        texture_manager_set_max_memory(texture_manager_get(), 50000000); // 50 MB
	}

	bool isPortrait;
	ReadManifest(&isPortrait);
	 
	self->isPortrait = isPortrait;
	
	 
	 // Fix orientation
	 bool swap = h > w;
	 swap ^= isPortrait;
	 if (swap) {
		 
		 int t = w;
		 w = h;
		 h = t;
	 }
	 
	 
	 //create our openglview and size it correctly
	 //TEALEAF_SPECIFIC_START
	 
	 frame = CGRectMake(0, 0, w, h);
	 OpenGLView *glView = [[OpenGLView alloc] initWithFrame:frame];
	 self.view = glView;
	 self.appDelegate.canvas = glView;
	 glView.frame = frame;
	 core_init_gl(1);
	 tealeaf_canvas_resize(w, h);
	 
	
	/*
	 * add a temporary imageview with the loading image.
	 * This smooths the transition between the launch image
	 * and our opengl loading image so there's no gap
	 */
	
	 NSURL *loading_path = [[ResourceLoader get] resolve:@"loading.png"];
	 NSData *data = [NSData dataWithContentsOfURL: loading_path];
	 UIImage *portrait = [UIImage imageWithData: data];
	 UIImage *loading_image = [[UIImage alloc] initWithCGImage: portrait.CGImage scale: 1.0 orientation: UIImageOrientationLeft];
	 
	 self.loading_image_view = [[UIImageView alloc] initWithImage:loading_image];
	 self.loading_image_view.frame = [self.appDelegate.window frame];
	 [self.appDelegate.window addSubview:self.loading_image_view];
	 
	 //add the openglview to our window
	 [self.appDelegate.window addSubview:self.view];
	 self.appDelegate.window.rootViewController = self;
	 
	 // PluginManager gets initialized after createJS() so that events are generated after core js is loaded
	 self.appDelegate.pluginManager = [[[PluginManager alloc] init] autorelease];
	
	 // Initialize text manager
	 if (!text_manager_init()) {
		 NSLOG(@"{tealeaf} ERROR: Unable to initialize text manager.");
	 }
	
	// Setup the JS runtime in the main thread
	if (!setup_js_runtime()) {
		NSLOG(@"{tealeaf} ERROR: Unable to setup javascript runtime.");
	}
   
	// Run JS initialization in another thread
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, (unsigned long)NULL), ^(void) {
		NSString *baseURL = [NSString stringWithFormat:@"http://%@:%d/", [self.appDelegate.config objectForKey:@"code_host"], [[self.appDelegate.config objectForKey:@"code_port"] intValue]];
		
		if (!core_init_js([baseURL UTF8String], [(NSString*)[self.appDelegate.config objectForKey:@"native_hash"] UTF8String])) {
			NSLOG(@"{tealeaf} ERROR: Unable to initialize javascript.");
		} else {
			[self onJSReady];
			[self.appDelegate postPauseEvent:self.appDelegate.wasPaused];
		}
	});
	
	[self.appDelegate.canvas startRendering];
	
	if ([[self.appDelegate.config objectForKey:@"remote_loading"] boolValue]) {
		UIRotationGestureRecognizer *rotationRecognizer =
		[[UIRotationGestureRecognizer alloc]
		initWithTarget:self
		action:@selector(rotationDetected:)];
		[self.view addGestureRecognizer:rotationRecognizer];
		[rotationRecognizer release];
		self.backAlertView = [[UIAlertView alloc] initWithTitle:@"Return to Games List?"
								   message:@"Would you like to return to the games list?"
								   delegate:self
								   cancelButtonTitle:@"No"
								   otherButtonTitles:@"Yes", nil];
	}
}

- (IBAction)rotationDetected:(UIGestureRecognizer *)sender {
	CGFloat velocity =
	[(UIRotationGestureRecognizer *)sender velocity];

	if (fabs(velocity) > 5) {
		if (!self.backAlertView.isVisible) {
			[self.backAlertView show];
		}
	}
}

static NSString *fixDictString(NSDictionary *dict, NSString *key) {
	NSString *value = [dict objectForKey:key];
	
	if (!value) {
		NSLOG(@"{settings} ERROR: Missing value for key %@", key);
		
		return @"";
	} else {
		return value;
	}
}

- (void)viewDidUnload {
	// Release any retained subviews of the main view.
	// e.g. self.myOutlet = nil;
}

- (void)assignCallback:(int)cb {
	callback = cb;
}

- (void)runCallback:(char *)arg {
	js_core* instance = [js_core lastJS];
	jsval args[] = { STRING_TO_JSVAL(JS_NewStringCopyZ(instance.cx, arg)) };
	[instance dispatchEvent: args count: 1];
}

- (void)sendSMSTo:(NSString *)number withMessage:(NSString *)msg andCallback:(int)cb {
	if([MFMessageComposeViewController canSendText]) {
		MFMessageComposeViewController* sms = [[MFMessageComposeViewController alloc] init];
		sms.body = msg;
		sms.recipients = [NSArray arrayWithObject: number];
		sms.messageComposeDelegate = self;
		sms.delegate = self;
		[self assignCallback: cb];
		[self presentModalViewController: sms animated:YES];
		[sms release];
	}
}

- (void)messageComposeViewController:(MFMessageComposeViewController *)controller didFinishWithResult:(MessageComposeResult)result {
	[self dismissModalViewControllerAnimated: YES];
	char args[128];
	// TODO replace with JS_* calls
	sprintf(args, "{\"name\":\"smsStatus\", \"id\":%d, \"result\":%d}", callback, (int)result);
	[self runCallback: args];
}

@end

@implementation UIAlertViewEx

- (void) dispatch:(int)callback {
	JSContext* cx = [[js_core lastJS] cx];
	JSObject* event = JS_NewObject(cx, NULL, NULL, NULL);
	jsval name = STRING_TO_JSVAL(JS_InternString(cx, "dialogButtonClicked"));
	jsval idv = INT_TO_JSVAL(callback);
	JS_SetProperty(cx, event, "name", &name);
	JS_SetProperty(cx, event, "id", &idv);

	jsval evt = OBJECT_TO_JSVAL(event);
	[[js_core lastJS] dispatchEvent:&evt count:1];
}

- (void) registerCallbacks:(int *)cbs length:(int)len {
	self->callbacks = (int*)malloc(len * sizeof(int));
	memcpy(self->callbacks, cbs, len);
	self->length = len;
}

- (void) dealloc {
	[ResourceLoader release];
	free(self->callbacks);
	[super dealloc];
}

@end
