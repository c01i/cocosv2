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
#include "CCFileUtilsMac.h"
#include <errno.h>
#include <fcntl.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

static NSString *screenshotFilename(NSBundle *bundle, NSDate *date)
{
    NSString *applicationName = [bundle objectForInfoDictionaryKey:@"CFBundleDisplayName"];
    if (![applicationName length]) applicationName = [bundle objectForInfoDictionaryKey:@"CFBundleName"];
    if (![applicationName length]) applicationName = [[NSProcessInfo processInfo] processName];

    NSDateFormatter *formatter = [[[NSDateFormatter alloc] init] autorelease];
    [formatter setLocale:[[[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"] autorelease]];
    [formatter setCalendar:[[[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian] autorelease]];
    [formatter setTimeZone:[NSTimeZone localTimeZone]];
    [formatter setDateFormat:@"yyyyMMddHHmmss-SSS"];
    return [NSString stringWithFormat:@"%@-ss-%@.png", applicationName, [formatter stringFromDate:date]];
}


static NSString *const kResolutionWidthKey = @"HelloLuaResolutionWidth";
static NSString *const kResolutionHeightKey = @"HelloLuaResolutionHeight";
static NSString *const kZoomPercentKey = @"HelloLuaZoomPercent";
static NSString *const kHasWindowOriginKey = @"HelloLuaHasWindowOrigin";
static NSString *const kWindowOriginXKey = @"HelloLuaWindowOriginX";
static NSString *const kWindowOriginYKey = @"HelloLuaWindowOriginY";

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
        NSArray *arguments = [[NSProcessInfo processInfo] arguments];
        NSString *workingDirectory = nil;
        for (NSUInteger i = 1; i < [arguments count]; ++i) {
            if (![[arguments objectAtIndex:i] isEqualToString:@"--workdir"]) continue;
            if (workingDirectory || i + 1 >= [arguments count] ||
                ![[arguments objectAtIndex:i + 1] length] ||
                [[arguments objectAtIndex:i + 1] hasPrefix:@"--"]) {
                fprintf(stderr, "HelloLua: --workdir requires exactly one directory and may appear only once.\n");
                exit(2);
            }
            workingDirectory = [arguments objectAtIndex:++i];
        }
        if (workingDirectory) {
            cocos2d::CCFileUtilsMac *files = static_cast<cocos2d::CCFileUtilsMac *>(cocos2d::CCFileUtils::sharedFileUtils());
            if (!files->setWorkingDirectory([workingDirectory UTF8String])) {
                fprintf(stderr, "HelloLua: unable to use --workdir directory: %s\n", [workingDirectory UTF8String]);
                exit(2);
            }
        }
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
        // Keep the controller-owned window alive through applicationWillTerminate.
        [window setReleasedWhenClosed:NO];

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
		[window setTitle:@"HelloLua"];
		if (selectedZoom != 1.0f) [glView setFrameZoomFactor:selectedZoom];
		[self restoreWindowPosition];
		[window setDelegate:self];
		[window makeKeyAndOrderFront:self];
		[window setAcceptsMouseMovedEvents:NO];
		[[glView openGLContext] makeCurrentContext];
		[glView lockOpenGLContext];
        BOOL sceneReady = [glView setScenePixelSize:NSMakeSize(selectedWidth, selectedHeight)];
        [glView unlockOpenGLContext];
        if (!sceneReady) {
            [self showScreenshotError:@"Unable to create the original-resolution rendering target."];
            [NSApp terminate:self];
            return;
        }
        [self setupViewMenu];

		cocos2d::CCApplication::sharedApplication()->run();
        if (!s_sharedApplication.isSceneReady()) {
            fprintf(stderr, "HelloLua: Lua scene initialization failed.\n");
            exit(1);
        }
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
		return [[support stringByAppendingPathComponent:@"HelloLua"]
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

		// Open once without following symlinks or blocking on a FIFO. Validate
		// that same descriptor, then read no more than one byte past the limit.
		int fd = open([path fileSystemRepresentation], O_RDONLY | O_NOFOLLOW | O_NONBLOCK);
		if (fd < 0) {
			NSLog(@"Unable to open resolution config %@: %s", path, strerror(errno));
			return fallback;
		}
		struct stat fileInfo;
		if (fstat(fd, &fileInfo) != 0 || !S_ISREG(fileInfo.st_mode)) {
			NSLog(@"Resolution config %@ is not a regular file; using defaults", path);
			close(fd);
			return fallback;
		}
		const NSUInteger readLimit = 1024 * 1024 + 1;
		NSMutableData *data = [NSMutableData dataWithLength:readLimit];
		NSUInteger count = 0;
		while (count < readLimit) {
			ssize_t amount = read(fd, (char *)[data mutableBytes] + count, readLimit - count);
			if (amount < 0 && errno == EINTR) continue;
			if (amount < 0) {
				NSLog(@"Unable to read resolution config %@: %s", path, strerror(errno));
				close(fd);
				return fallback;
			}
			if (amount == 0) break;
			count += (NSUInteger)amount;
		}
		close(fd);
		[data setLength:count];
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
		cocos2d::CCDirector::sharedDirector()->stopAnimation();
		cocos2d::CCDirector::sharedDirector()->end();
        [window setDelegate:nil];
        [window release];
        [glView release];
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
		[alert setMessageText:@"Restart HelloLua to apply the selected resolution."];
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
		[panel setNameFieldStringValue:screenshotFilename([NSBundle mainBundle], [NSDate date])];
		[panel setAllowedFileTypes:[NSArray arrayWithObject:@"png"]];
		if ([panel runModal] != NSFileHandlingPanelOKButton) return;

        // Read the original scene target, never the scaled window framebuffer.
        [glView lockOpenGLContext];
        NSBitmapImageRep *output = [[glView sceneSnapshot] retain];
        [glView unlockOpenGLContext];
        if (!output) {
            [self showScreenshotError:@"Unable to read the original-resolution rendering target."];
            return;
        }
		NSData *png = [output representationUsingType:NSPNGFileType properties:[NSDictionary dictionary]];
        [output release];
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
