/****************************************************************************
 Copyright (c) 2010 cocos2d-x.org
 
 http://www.cocos2d-x.org
 
 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:
 
 The above copyright notice and this permission notice shall be included in
 all copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 THE SOFTWARE.
 ****************************************************************************/
 
#import "AppController.h"
#import "AppDelegate.h"
#import "CCEGLView.h"

static NSString *const kResolutionWidthKey = @"TestCppResolutionWidth";
static NSString *const kResolutionHeightKey = @"TestCppResolutionHeight";
static NSString *const kZoomPercentKey = @"TestCppZoomPercent";
static NSString *const kHasWindowOriginKey = @"TestCppHasWindowOrigin";
static NSString *const kWindowOriginXKey = @"TestCppWindowOriginX";
static NSString *const kWindowOriginYKey = @"TestCppWindowOriginY";

@interface AppController ()
- (NSString *)resolutionConfigPath;
- (NSArray *)loadResolutionPresets;
- (void)setupViewMenu;
- (void)updateViewMenu;
- (void)showScreenshotError:(NSString *)message;
- (void)restoreWindowPosition;
- (void)saveWindowPosition;
@end

@implementation AppController

	static AppDelegate s_sharedApplication;

	@synthesize window, glView;

	-(void) applicationDidFinishLaunching:(NSNotification *)aNotification
	{
		resolutionPresets = [[self loadResolutionPresets] retain];
		NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
		selectedWidth = [defaults integerForKey:kResolutionWidthKey];
		selectedHeight = [defaults integerForKey:kResolutionHeightKey];
		BOOL validSelection = NO;
		for (NSDictionary *preset in resolutionPresets) {
			if ([[preset objectForKey:@"width"] integerValue] == selectedWidth &&
				[[preset objectForKey:@"height"] integerValue] == selectedHeight) {
				validSelection = YES;
				break;
			}
		}
		if (!validSelection) {
			selectedWidth = 480;
			selectedHeight = 320;
		}
		NSInteger zoomPercent = [defaults integerForKey:kZoomPercentKey];
		int allowedZoom[] = {25, 50, 75, 100, 150, 200};
		selectedZoom = 1.0f;
		for (int i = 0; i < 6; ++i) {
			if (zoomPercent == allowedZoom[i]) selectedZoom = zoomPercent / 100.0f;
		}

		// create the window
		// note that using NSResizableWindowMask causes the window to be a little
		// smaller and therefore ipad graphics are not loaded
		NSRect rect = NSMakeRect(200, 200, selectedWidth, selectedHeight);
		window = [[NSWindow alloc] initWithContentRect:rect
			styleMask:( NSClosableWindowMask | NSTitledWindowMask )
			backing:NSBackingStoreBuffered
			defer:YES];
        
        NSOpenGLPixelFormatAttribute attributes[] = {
            NSOpenGLPFADoubleBuffer,
            NSOpenGLPFADepthSize, 24,
            NSOpenGLPFAStencilSize, 8,
            0
        };
        
        NSOpenGLPixelFormat *pixelFormat = [[[NSOpenGLPixelFormat alloc] initWithAttributes:attributes] autorelease];
		
		// allocate our GL view
		// (isn't there already a shared EAGLView?)
		glView = [[EAGLView alloc] initWithFrame:NSMakeRect(0, 0, selectedWidth, selectedHeight)
			pixelFormat:pixelFormat];

		// set window parameters
		[window becomeFirstResponder];
		[window setContentView:glView];
		[window setTitle:@"TestCpp"];
		if (selectedZoom != 1.0f) [glView setFrameZoomFactor:selectedZoom];
		[self restoreWindowPosition];
		[window setDelegate:self];
		[window makeKeyAndOrderFront:self];
		[window setAcceptsMouseMovedEvents:NO];
		[[glView openGLContext] makeCurrentContext];
		[self setupViewMenu];

		cocos2d::CCApplication::sharedApplication()->run();
	}

	- (void)restoreWindowPosition
	{
		NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
		if (![defaults boolForKey:kHasWindowOriginKey]) return;
		double x = [defaults doubleForKey:kWindowOriginXKey];
		double y = [defaults doubleForKey:kWindowOriginYKey];
		if (!isfinite(x) || !isfinite(y)) return;

		NSRect frame = [window frame];
		frame.origin = NSMakePoint(x, y);
		NSScreen *screen = nil;
		for (NSScreen *candidate in [NSScreen screens]) {
			if (NSIntersectsRect(frame, [candidate visibleFrame])) {
				screen = candidate;
				break;
			}
		}
		if (!screen) screen = [NSScreen mainScreen];
		if (!screen) return;
		NSRect visible = [screen visibleFrame];
		// Keep at least 80 points of title bar horizontally and 30 vertically visible.
		frame.origin.x = fmax(NSMinX(visible) - NSWidth(frame) + 80,
			fmin(frame.origin.x, NSMaxX(visible) - 80));
		frame.origin.y = fmax(NSMinY(visible) - NSHeight(frame) + 30,
			fmin(frame.origin.y, NSMaxY(visible) - NSHeight(frame)));
		[window setFrameOrigin:frame.origin];
	}

	- (void)saveWindowPosition
	{
		if (!window || [glView isFullScreen]) return;
		NSPoint origin = [window frame].origin;
		NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
		[defaults setDouble:origin.x forKey:kWindowOriginXKey];
		[defaults setDouble:origin.y forKey:kWindowOriginYKey];
		[defaults setBool:YES forKey:kHasWindowOriginKey];
	}

	- (void)windowDidMove:(NSNotification *)notification
	{
		if ([notification object] == window) [self saveWindowPosition];
	}

	- (void)applicationWillTerminate:(NSNotification *)notification
	{
		[self saveWindowPosition];
		NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
		[defaults setInteger:(NSInteger)roundf(selectedZoom * 100) forKey:kZoomPercentKey];
		[defaults synchronize];
	}

	- (NSString *)resolutionConfigPath
	{
		NSString *support = [NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory,
			NSUserDomainMask, YES) objectAtIndex:0];
		return [[support stringByAppendingPathComponent:@"TestCpp"]
			stringByAppendingPathComponent:@"resolutions.json"];
	}

	- (NSArray *)loadResolutionPresets
	{
		NSArray *fallback = [NSArray arrayWithObjects:
			[NSDictionary dictionaryWithObjectsAndKeys:@"480 × 320", @"name", @480, @"width", @320, @"height", nil],
			[NSDictionary dictionaryWithObjectsAndKeys:@"960 × 640", @"name", @960, @"width", @640, @"height", nil],
			[NSDictionary dictionaryWithObjectsAndKeys:@"640 × 480", @"name", @640, @"width", @480, @"height", nil], nil];
		NSString *path = [self resolutionConfigPath];
		NSFileManager *files = [NSFileManager defaultManager];
		if (![files fileExistsAtPath:path]) {
			NSError *error = nil;
			NSString *directory = [path stringByDeletingLastPathComponent];
			[files createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:&error];
			if (!error) {
				NSDictionary *document = [NSDictionary dictionaryWithObject:fallback forKey:@"resolutions"];
				NSData *json = [NSJSONSerialization dataWithJSONObject:document
					options:NSJSONWritingPrettyPrinted error:&error];
				if (json && ![json writeToFile:path options:NSDataWritingAtomic error:&error]) {
					NSLog(@"Unable to write %@: %@", path, error);
				}
			} else {
				NSLog(@"Unable to create %@: %@", directory, error);
			}
		}

		// Read one byte past the limit so a large or symlinked file cannot make
		// startup allocate and parse an unbounded amount of user-controlled data.
		NSError *readError = nil;
		NSDictionary *attributes = [files attributesOfItemAtPath:path error:&readError];
		if (![[attributes objectForKey:NSFileType] isEqualToString:NSFileTypeRegular]) {
			NSLog(@"Unable to read regular resolution config %@: %@", path, readError);
			return fallback;
		}
		NSFileHandle *handle = [NSFileHandle fileHandleForReadingAtPath:path];
		if (!handle) {
			NSLog(@"Unable to open resolution config %@; using defaults", path);
			return fallback;
		}
		NSData *data = nil;
		@try {
			data = [handle readDataOfLength:1024 * 1024 + 1];
		} @catch (NSException *exception) {
			NSLog(@"Unable to read resolution config %@: %@", path, exception);
		}
		[handle closeFile];
		if (!data) return fallback;
		if ([data length] > 1024 * 1024) {
			NSLog(@"Resolution config %@ exceeds 1 MiB; using defaults", path);
			return fallback;
		}
		NSError *error = nil;
		id document = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
		if (![document isKindOfClass:[NSDictionary class]] ||
			![[document objectForKey:@"resolutions"] isKindOfClass:[NSArray class]]) {
			NSLog(@"Invalid resolution config %@: %@", path, error);
			return fallback;
		}

		NSMutableArray *presets = [NSMutableArray array];
		NSMutableSet *seen = [NSMutableSet set];
		for (id entry in [document objectForKey:@"resolutions"]) {
			if (![entry isKindOfClass:[NSDictionary class]]) continue;
			id name = [entry objectForKey:@"name"];
			id width = [entry objectForKey:@"width"];
			id height = [entry objectForKey:@"height"];
			if (![name isKindOfClass:[NSString class]] || [name length] > 80 ||
				![[name stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] length] ||
				![width isKindOfClass:[NSNumber class]] || ![height isKindOfClass:[NSNumber class]]) continue;
			double w = [width doubleValue], h = [height doubleValue];
			if (!isfinite(w) || !isfinite(h) || floor(w) != w || floor(h) != h ||
				w < 320 || h < 320 || w > 4096 || h > 4096 || w * h > 16777216) continue;
			NSString *key = [NSString stringWithFormat:@"%d:%d", (int)w, (int)h];
			if ([seen containsObject:key]) continue;
			[seen addObject:key];
			[presets addObject:[NSDictionary dictionaryWithObjectsAndKeys:name, @"name",
				[NSNumber numberWithInt:(int)w], @"width", [NSNumber numberWithInt:(int)h], @"height", nil]];
			if ([presets count] == 128) break;
		}
		if (![presets count]) {
			NSLog(@"No valid resolutions in %@; using defaults", path);
			return fallback;
		}
		if (![seen containsObject:@"480:320"]) {
			if ([presets count] == 128) [presets removeLastObject];
			[presets insertObject:[fallback objectAtIndex:0] atIndex:0];
		}
		return presets;
	}

	- (void)setupViewMenu
	{
		NSMenu *viewMenu = [[[NSApp mainMenu] itemWithTitle:@"View"] submenu];
		if (!viewMenu) return;
		resolutionMenu = [[[NSMenu alloc] initWithTitle:@"Resolution"] autorelease];
		NSMenuItem *resolutionItem = [[[NSMenuItem alloc] initWithTitle:@"Resolution"
			action:nil keyEquivalent:@""] autorelease];
		[resolutionItem setSubmenu:resolutionMenu];
		[viewMenu addItem:resolutionItem];
		NSInteger index = 0;
		for (NSDictionary *preset in resolutionPresets) {
			NSMenuItem *item = [[[NSMenuItem alloc] initWithTitle:[preset objectForKey:@"name"]
				action:@selector(selectResolution:) keyEquivalent:@""] autorelease];
			[item setTarget:self];
			[item setTag:index++];
			[resolutionMenu addItem:item];
		}
		[resolutionMenu addItem:[NSMenuItem separatorItem]];
		NSMenuItem *openItem = [[[NSMenuItem alloc] initWithTitle:@"Open Resolution Config…"
			action:@selector(openResolutionConfig:) keyEquivalent:@""] autorelease];
		[openItem setTarget:self];
		[resolutionMenu addItem:openItem];

		zoomMenu = [[[NSMenu alloc] initWithTitle:@"Zoom"] autorelease];
		NSMenuItem *zoomItem = [[[NSMenuItem alloc] initWithTitle:@"Zoom"
			action:nil keyEquivalent:@""] autorelease];
		[zoomItem setSubmenu:zoomMenu];
		[viewMenu addItem:zoomItem];
		int scales[] = {25, 50, 75, 100, 150, 200};
		for (int i = 0; i < 6; ++i) {
			NSMenuItem *item = [[[NSMenuItem alloc] initWithTitle:[NSString stringWithFormat:@"%d%%", scales[i]]
				action:@selector(selectZoom:) keyEquivalent:@""] autorelease];
			[item setTarget:self];
			[item setTag:scales[i]];
			[zoomMenu addItem:item];
		}
		[viewMenu addItem:[NSMenuItem separatorItem]];
		NSMenuItem *screenshotItem = [[[NSMenuItem alloc] initWithTitle:@"Save Screenshot…"
			action:@selector(saveScreenshot:) keyEquivalent:@"s"] autorelease];
		[screenshotItem setKeyEquivalentModifierMask:NSCommandKeyMask | NSShiftKeyMask];
		[screenshotItem setTarget:self];
		[viewMenu addItem:screenshotItem];
		[self updateViewMenu];
	}

	- (void)updateViewMenu
	{
		for (NSMenuItem *item in [resolutionMenu itemArray]) {
			NSInteger index = [item tag];
			if ([item action] != @selector(selectResolution:) || index >= [resolutionPresets count]) continue;
			NSDictionary *preset = [resolutionPresets objectAtIndex:index];
			[item setState:([[preset objectForKey:@"width"] integerValue] == selectedWidth &&
				[[preset objectForKey:@"height"] integerValue] == selectedHeight) ? NSOnState : NSOffState];
		}
		for (NSMenuItem *item in [zoomMenu itemArray]) {
			[item setState:([item tag] == (NSInteger)roundf(selectedZoom * 100)) ? NSOnState : NSOffState];
		}
	}

	-(BOOL) applicationShouldTerminateAfterLastWindowClosed:(NSApplication*)theApplication
	{
		return YES;
	}

	-(void) dealloc
	{
		cocos2d::CCDirector::sharedDirector()->end();
		[resolutionPresets release];
		[super dealloc];
	}

#pragma mark -
#pragma mark IB Actions

	-(IBAction) toggleFullScreen:(id)sender
	{
		EAGLView* pView = [EAGLView sharedEGLView];
		[pView setFullScreen:!pView.isFullScreen];
	}

	-(IBAction) exitFullScreen:(id)sender
	{
		[[EAGLView sharedEGLView] setFullScreen:NO];
	}

	-(IBAction)selectResolution:(id)sender
	{
		NSInteger index = [sender tag];
		if (index < 0 || index >= [resolutionPresets count]) return;
		NSDictionary *preset = [resolutionPresets objectAtIndex:index];
		NSInteger width = [[preset objectForKey:@"width"] integerValue];
		NSInteger height = [[preset objectForKey:@"height"] integerValue];
		if (width == selectedWidth && height == selectedHeight) return;
		selectedWidth = width;
		selectedHeight = height;
		NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
		[defaults setInteger:width forKey:kResolutionWidthKey];
		[defaults setInteger:height forKey:kResolutionHeightKey];
		[defaults synchronize];
		[self saveWindowPosition];
		[self updateViewMenu];
		NSAlert *alert = [[[NSAlert alloc] init] autorelease];
		[alert setMessageText:@"Restart TestCpp to apply the selected resolution."];
		[alert runModal];
	}

	-(IBAction)selectZoom:(id)sender
	{
		selectedZoom = [sender tag] / 100.0f;
		[glView setFrameZoomFactor:selectedZoom];
		[[NSUserDefaults standardUserDefaults] setInteger:[sender tag] forKey:kZoomPercentKey];
		[self saveWindowPosition];
		[self updateViewMenu];
	}

	-(IBAction)openResolutionConfig:(id)sender
	{
		if (![[NSWorkspace sharedWorkspace] openFile:[self resolutionConfigPath]]) {
			NSAlert *alert = [[[NSAlert alloc] init] autorelease];
			[alert setMessageText:@"Unable to open resolutions.json"];
			[alert runModal];
		}
	}

	-(IBAction)saveScreenshot:(id)sender
	{
		NSSavePanel *panel = [NSSavePanel savePanel];
		[panel setNameFieldStringValue:@"TestCpp.png"];
		[panel setAllowedFileTypes:[NSArray arrayWithObject:@"png"]];
		if ([panel runModal] != NSFileHandlingPanelOKButton) return;

		// The frame size belongs to the current GL view. A newly selected preset may
		// still be waiting for an application restart.
		cocos2d::CCSize frameSize = cocos2d::CCEGLView::sharedOpenGLView()->getFrameSize();
		NSInteger outputWidth = (NSInteger)roundf(frameSize.width);
		NSInteger outputHeight = (NSInteger)roundf(frameSize.height);
		NSRect backing = [glView convertRectToBacking:[glView bounds]];
		NSInteger pixelWidth = (NSInteger)roundf(backing.size.width);
		NSInteger pixelHeight = (NSInteger)roundf(backing.size.height);
		if (outputWidth <= 0 || outputHeight <= 0 || pixelWidth <= 0 || pixelHeight <= 0 ||
			pixelWidth > 16384 || pixelHeight > 16384 ||
			(long long)pixelWidth * pixelHeight > 67108864) {
			[self showScreenshotError:@"Invalid view size for screenshot."];
			return;
		}

		size_t rowBytes = (size_t)pixelWidth * 4;
		unsigned char *pixels = (unsigned char *)malloc(rowBytes * (size_t)pixelHeight);
		if (!pixels) {
			[self showScreenshotError:@"Unable to allocate screenshot buffer."];
			return;
		}
		[glView lockOpenGLContext];
		GLint previousReadBuffer = GL_BACK;
		GLint previousPackAlignment = 4;
		glGetIntegerv(GL_READ_BUFFER, &previousReadBuffer);
		glGetIntegerv(GL_PACK_ALIGNMENT, &previousPackAlignment);
		glReadBuffer(GL_FRONT);
		glPixelStorei(GL_PACK_ALIGNMENT, 1);
		while (glGetError() != GL_NO_ERROR) {}
		glReadPixels(0, 0, (GLsizei)pixelWidth, (GLsizei)pixelHeight,
			GL_RGBA, GL_UNSIGNED_BYTE, pixels);
		GLenum readError = glGetError();
		glReadBuffer(previousReadBuffer);
		glPixelStorei(GL_PACK_ALIGNMENT, previousPackAlignment);
		[glView unlockOpenGLContext];
		if (readError != GL_NO_ERROR) {
			free(pixels);
			[self showScreenshotError:@"Unable to read the OpenGL view."];
			return;
		}

		NSBitmapImageRep *source = [[[NSBitmapImageRep alloc]
			initWithBitmapDataPlanes:NULL pixelsWide:pixelWidth pixelsHigh:pixelHeight
			bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO
			colorSpaceName:NSDeviceRGBColorSpace bytesPerRow:rowBytes bitsPerPixel:32] autorelease];
		if (!source) {
			free(pixels);
			[self showScreenshotError:@"Unable to create screenshot image."];
			return;
		}
		unsigned char *destination = [source bitmapData];
		for (NSInteger y = 0; y < pixelHeight; ++y) {
			memcpy(destination + (size_t)y * [source bytesPerRow],
				pixels + (size_t)(pixelHeight - 1 - y) * rowBytes, rowBytes);
		}
		free(pixels);

		NSBitmapImageRep *output = source;
		if (pixelWidth != outputWidth || pixelHeight != outputHeight) {
			output = [[[NSBitmapImageRep alloc]
				initWithBitmapDataPlanes:NULL pixelsWide:outputWidth pixelsHigh:outputHeight
				bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO
				colorSpaceName:NSDeviceRGBColorSpace bytesPerRow:outputWidth * 4 bitsPerPixel:32] autorelease];
			if (!output) {
				[self showScreenshotError:@"Unable to scale screenshot image."];
				return;
			}
			NSGraphicsContext *context = [NSGraphicsContext graphicsContextWithBitmapImageRep:output];
			[NSGraphicsContext saveGraphicsState];
			[NSGraphicsContext setCurrentContext:context];
			[context setImageInterpolation:NSImageInterpolationHigh];
			[source drawInRect:NSMakeRect(0, 0, outputWidth, outputHeight)];
			[NSGraphicsContext restoreGraphicsState];
		}
		NSData *png = [output representationUsingType:NSPNGFileType properties:[NSDictionary dictionary]];
		if (!png || ![png writeToURL:[panel URL] atomically:YES]) {
			[self showScreenshotError:@"Unable to save the screenshot PNG."];
		}
	}

	-(void)showScreenshotError:(NSString *)message
	{
		NSAlert *alert = [[[NSAlert alloc] init] autorelease];
		[alert setMessageText:message];
		[alert runModal];
	}

@end
