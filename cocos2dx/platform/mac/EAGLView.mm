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

/*
 * Idea of subclassing NSOpenGLView was taken from  "TextureUpload" Apple's sample
 */

#import <Availability.h>

#import "EAGLView.h"
#import "CCEGLView.h"
#import <OpenGL/gl.h>
#import "CCDirector.h"
#import "ccConfig.h"
#import "CCSet.h"
#import "CCTouch.h"
#import "CCIMEDispatcher.h"
#import "CCWindow.h"
#import "CCEventDispatcher.h"
#import "CCEGLView.h"


//USING_NS_CC;
static EAGLView *view;

@implementation EAGLView

@synthesize eventDelegate = eventDelegate_, isFullScreen = isFullScreen_, frameZoomFactor=frameZoomFactor_;

+(id) sharedEGLView
{
	return view;
}

- (id) initWithFrame:(NSRect)frameRect
{
	self = [self initWithFrame:frameRect shareContext:nil];
	return self;
}

- (id) initWithFrame:(NSRect)frameRect shareContext:(NSOpenGLContext*)context
{
    NSOpenGLPixelFormatAttribute attribs[] =
    {
//		NSOpenGLPFAAccelerated,
//		NSOpenGLPFANoRecovery,
		NSOpenGLPFADoubleBuffer,
		NSOpenGLPFADepthSize, 24,
		
		0
    };
	
	NSOpenGLPixelFormat *pixelFormat = [[NSOpenGLPixelFormat alloc] initWithAttributes:attribs];
	
	if (!pixelFormat)
		NSLog(@"No OpenGL pixel format");
	
	if( (self = [super initWithFrame:frameRect pixelFormat:[pixelFormat autorelease]]) ) {
		
		if( context )
			[self setOpenGLContext:context];

		// event delegate
		eventDelegate_ = [CCEventDispatcher sharedDispatcher];
	}
    
    cocos2d::CCEGLView::sharedOpenGLView()->setFrameSize(frameRect.size.width, frameRect.size.height);
    
    frameZoomFactor_ = 1.0f;
	
	view = self;
	return self;
}

- (id) initWithFrame:(NSRect)frameRect pixelFormat:(NSOpenGLPixelFormat *)format{
    // event delegate
    eventDelegate_ = [CCEventDispatcher sharedDispatcher];
    
    cocos2d::CCEGLView::sharedOpenGLView()->setFrameSize(frameRect.size.width, frameRect.size.height);
    
    frameZoomFactor_ = 1.0f;
	
	view = self;
    
    [super initWithFrame:frameRect pixelFormat:format];

    return self;
}

- (void) update
{
	// XXX: Should I do something here ?
	[super update];
}

- (void) prepareOpenGL
{
	// XXX: Initialize OpenGL context

	[super prepareOpenGL];
	
	// Make this openGL context current to the thread
	// (i.e. all openGL on this thread calls will go to this context)
	[[self openGLContext] makeCurrentContext];
	
	// Synchronize buffer swaps with vertical refresh rate
	GLint swapInt = 1;
	[[self openGLContext] setValues:&swapInt forParameter:NSOpenGLCPSwapInterval];	

//	GLint order = -1;
//	[[self openGLContext] setValues:&order forParameter:NSOpenGLCPSurfaceOrder];
}

- (NSUInteger) depthFormat
{
	return 24;
}

- (void) setFrameZoomFactor:(float)frameZoomFactor
{
    if (frameZoomFactor <= 0 || ![self window]) return;

    // The view is already scaled; derive its unscaled content size before resizing.
    NSSize logicalSize = NSMakeSize([self bounds].size.width / frameZoomFactor_,
                                   [self bounds].size.height / frameZoomFactor_);
    NSPoint topLeft = NSMakePoint(NSMinX([[self window] frame]), NSMaxY([[self window] frame]));
    frameZoomFactor_ = frameZoomFactor;
    [[self window] setContentSize:NSMakeSize(roundf(logicalSize.width * frameZoomFactor),
                                            roundf(logicalSize.height * frameZoomFactor))];
    [[self window] setFrameTopLeftPoint:topLeft];
}

- (void) reshape
{
	// We draw on a secondary thread through the display link
	// When resizing the view, -reshape is called automatically on the main thread
	// Add a mutex around to avoid the threads accessing the context simultaneously when resizing

	[self lockOpenGLContext];
	
//	NSRect rect = [self bounds];
	
	cocos2d::CCDirector *director = cocos2d::CCDirector::sharedDirector();
//	CGSize size = NSSizeToCGSize(rect.size);
//	cocos2d::CCSize ccsize = cocos2d::CCSizeMake(size.width, size.height);
	//director->reshapeProjection(ccsize);
	
	// avoid flicker
	director->drawScene();
//	[self setNeedsDisplay:YES];
	
	[self unlockOpenGLContext];
}

-(void) lockOpenGLContext
{
	NSOpenGLContext *glContext = [self openGLContext];
	NSAssert( glContext, @"FATAL: could not get openGL context");

	[glContext makeCurrentContext];
	CGLLockContext((CGLContextObj)[glContext CGLContextObj]);
}

-(void) unlockOpenGLContext
{
	NSOpenGLContext *glContext = [self openGLContext];
	NSAssert( glContext, @"FATAL: could not get openGL context");

	CGLUnlockContext((CGLContextObj)[glContext CGLContextObj]);
}

- (void) dealloc
{
	CCLOGINFO(@"cocos2d: deallocing EAGLView %@", self);
	[self lockOpenGLContext];
	[self setScenePixelSize:NSZeroSize];
	[self unlockOpenGLContext];
	[super dealloc];
}
	
-(int) getWidth
{
	NSSize bound = [self bounds].size;
	return bound.width;
}

-(int) getHeight
{
	NSSize bound = [self bounds].size;
	return bound.height;
}

-(void) swapBuffers
{
    if (!sceneFramebuffer_) return;
    GLint oldRead, oldDraw;
    glGetIntegerv(GL_READ_FRAMEBUFFER_BINDING, &oldRead);
    glGetIntegerv(GL_DRAW_FRAMEBUFFER_BINDING, &oldDraw);
    GLboolean scissor = glIsEnabled(GL_SCISSOR_TEST);
    glDisable(GL_SCISSOR_TEST);
    glBindFramebuffer(GL_READ_FRAMEBUFFER, sceneFramebuffer_);
    glBindFramebuffer(GL_DRAW_FRAMEBUFFER, 0);
    NSRect backing = [self convertRectToBacking:[self bounds]];
    glBlitFramebuffer(0, 0, (GLint)scenePixelSize_.width, (GLint)scenePixelSize_.height,
                      0, 0, (GLint)roundf(backing.size.width), (GLint)roundf(backing.size.height),
                      GL_COLOR_BUFFER_BIT, GL_LINEAR);
    // NSOpenGLContext flushBuffer presents the window's default framebuffer.
    // The director rebinds the scene target at the start of the next frame.
    glBindFramebuffer(GL_READ_FRAMEBUFFER, (GLuint)oldRead == sceneFramebuffer_ ? 0 : oldRead);
    glBindFramebuffer(GL_DRAW_FRAMEBUFFER, (GLuint)oldDraw == sceneFramebuffer_ ? 0 : oldDraw);
    if (scissor) glEnable(GL_SCISSOR_TEST);
}

- (BOOL)usesSceneFramebuffer
{
    return sceneFramebuffer_ != 0;
}

- (BOOL)setScenePixelSize:(NSSize)size
{
    if (NSEqualSizes(size, scenePixelSize_)) return YES;
    if (!NSEqualSizes(size, NSZeroSize) &&
        (!isfinite(size.width) || !isfinite(size.height) ||
         size.width < 1 || size.height < 1 || size.width > 4096 || size.height > 4096 ||
         floor(size.width) != size.width || floor(size.height) != size.height)) return NO;

    GLint oldRead, oldDraw, oldRenderbuffer;
    glGetIntegerv(GL_READ_FRAMEBUFFER_BINDING, &oldRead);
    glGetIntegerv(GL_DRAW_FRAMEBUFFER_BINDING, &oldDraw);
    glGetIntegerv(GL_RENDERBUFFER_BINDING, &oldRenderbuffer);
    GLuint framebuffer = 0, color = 0, depthStencil = 0;
    if (!NSEqualSizes(size, NSZeroSize)) {
        glGenFramebuffers(1, &framebuffer);
        glBindFramebuffer(GL_FRAMEBUFFER, framebuffer);
        glGenRenderbuffers(1, &color);
        glBindRenderbuffer(GL_RENDERBUFFER, color);
        glRenderbufferStorage(GL_RENDERBUFFER, GL_RGBA8, (GLsizei)size.width, (GLsizei)size.height);
        glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, color);
        glGenRenderbuffers(1, &depthStencil);
        glBindRenderbuffer(GL_RENDERBUFFER, depthStencil);
        glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH24_STENCIL8, (GLsizei)size.width, (GLsizei)size.height);
        glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_RENDERBUFFER, depthStencil);
        glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_STENCIL_ATTACHMENT, GL_RENDERBUFFER, depthStencil);
        GLenum status = glCheckFramebufferStatus(GL_FRAMEBUFFER);
        if (!framebuffer || !color || !depthStencil || status != GL_FRAMEBUFFER_COMPLETE) {
            NSLog(@"Unable to allocate scene framebuffer %.0fx%.0f (status 0x%x)", size.width, size.height, status);
            glBindFramebuffer(GL_READ_FRAMEBUFFER, oldRead);
            glBindFramebuffer(GL_DRAW_FRAMEBUFFER, oldDraw);
            glBindRenderbuffer(GL_RENDERBUFFER, oldRenderbuffer);
            glDeleteRenderbuffers(1, &depthStencil);
            glDeleteRenderbuffers(1, &color);
            glDeleteFramebuffers(1, &framebuffer);
            return NO;
        }
    }
    // Replace only after complete allocation; existing targets survive failure.
    if ((GLuint)oldRead == sceneFramebuffer_) oldRead = framebuffer;
    if ((GLuint)oldDraw == sceneFramebuffer_) oldDraw = framebuffer;
    if ((GLuint)oldRenderbuffer == sceneColorBuffer_ ||
        (GLuint)oldRenderbuffer == sceneDepthStencilBuffer_) oldRenderbuffer = 0;
    glBindFramebuffer(GL_READ_FRAMEBUFFER, oldRead);
    glBindFramebuffer(GL_DRAW_FRAMEBUFFER, oldDraw);
    glBindRenderbuffer(GL_RENDERBUFFER, oldRenderbuffer);
    glDeleteRenderbuffers(1, &sceneDepthStencilBuffer_);
    glDeleteRenderbuffers(1, &sceneColorBuffer_);
    glDeleteFramebuffers(1, &sceneFramebuffer_);
    sceneFramebuffer_ = framebuffer;
    sceneColorBuffer_ = color;
    sceneDepthStencilBuffer_ = depthStencil;
    scenePixelSize_ = size;
    return YES;
}

- (void)beginSceneFrame
{
    if (!sceneFramebuffer_) return;
    glBindFramebuffer(GL_FRAMEBUFFER, sceneFramebuffer_);
    cocos2d::CCDirector::sharedDirector()->setViewport();
}

- (NSBitmapImageRep *)sceneSnapshot
{
    if (!sceneFramebuffer_) return nil;
    NSInteger width = (NSInteger)scenePixelSize_.width, height = (NSInteger)scenePixelSize_.height;
    NSBitmapImageRep *image = [[[NSBitmapImageRep alloc]
        initWithBitmapDataPlanes:NULL pixelsWide:width pixelsHigh:height
        bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO
        colorSpaceName:NSDeviceRGBColorSpace bytesPerRow:width * 4 bitsPerPixel:32] autorelease];
    if (!image) return nil;
    GLint oldRead, oldPack;
    glGetIntegerv(GL_READ_FRAMEBUFFER_BINDING, &oldRead);
    glGetIntegerv(GL_PACK_ALIGNMENT, &oldPack);
    glBindFramebuffer(GL_READ_FRAMEBUFFER, sceneFramebuffer_);
    glPixelStorei(GL_PACK_ALIGNMENT, 1);
    glReadPixels(0, 0, (GLsizei)width, (GLsizei)height, GL_RGBA, GL_UNSIGNED_BYTE, [image bitmapData]);
    GLenum error = glGetError();
    glBindFramebuffer(GL_READ_FRAMEBUFFER, oldRead);
    glPixelStorei(GL_PACK_ALIGNMENT, oldPack);
    if (error != GL_NO_ERROR) {
        NSLog(@"Unable to read scene framebuffer (GL error 0x%x)", error);
        return nil;
    }
    // GL rows start at the bottom; PNG rows start at the top.
    NSUInteger stride = [image bytesPerRow];
    NSMutableData *row = [NSMutableData dataWithLength:stride];
    unsigned char *pixels = [image bitmapData];
    for (NSInteger y = 0; y < height / 2; ++y) {
        unsigned char *top = pixels + y * stride;
        unsigned char *bottom = pixels + (height - 1 - y) * stride;
        memcpy([row mutableBytes], top, stride);
        memcpy(top, bottom, stride);
        memcpy(bottom, [row bytes], stride);
    }
    return image;
}

//
// setFullScreen code taken from GLFullScreen example by Apple
//
- (void) setFullScreen:(BOOL)fullscreen
{
	// Mac OS X 10.6 and later offer a simplified mechanism to create full-screen contexts
#if MAC_OS_X_VERSION_MIN_REQUIRED > MAC_OS_X_VERSION_10_5

    if (isFullScreen_ == fullscreen)
		return;

	EAGLView *openGLview = [[self class] sharedEGLView];

    if( fullscreen ) {
        originalWinRect_ = [openGLview frame];

        // Cache normal window and superview of openGLView
        if(!windowGLView_)
            windowGLView_ = [[openGLview window] retain];

        [superViewGLView_ release];
        superViewGLView_ = [[openGLview superview] retain];


        // Get screen size
        NSRect displayRect = [[NSScreen mainScreen] frame];

        // Create a screen-sized window on the display you want to take over
        fullScreenWindow_ = [[CCWindow alloc] initWithFrame:displayRect fullscreen:YES];

        // Remove glView from window
        [openGLview removeFromSuperview];

        // Set new frame
        [openGLview setFrame:displayRect];

        // Attach glView to fullscreen window
        [fullScreenWindow_ setContentView:openGLview];

        // Show the fullscreen window
        [fullScreenWindow_ makeKeyAndOrderFront:self];
		[fullScreenWindow_ makeMainWindow];
		//[fullScreenWindow_ setNextResponder:superViewGLView_];

    } else {

        // Remove glView from fullscreen window
        [openGLview removeFromSuperview];

        // Release fullscreen window
        [fullScreenWindow_ release];
        fullScreenWindow_ = nil;

        // Attach glView to superview
        [superViewGLView_ addSubview:openGLview];

        // Set new frame
        [openGLview setFrame:originalWinRect_];

        // Show the window
        [windowGLView_ makeKeyAndOrderFront:self];
		[windowGLView_ makeMainWindow];
    }
	
	// issue #1189
	[windowGLView_ makeFirstResponder:openGLview];

    isFullScreen_ = fullscreen;

    //[openGLview retain]; // Retain +1

	// is this necessary?
    // re-configure glView
	//cocos2d::CCDirector *director = cocos2d::CCDirector::sharedDirector();
	//director->setOpenGLView(openGLview); //[self setView:openGLview];

    //[openGLview release]; // Retain -1

    [openGLview setNeedsDisplay:YES];
#else
#error Full screen is not supported for Mac OS 10.5 or older yet
#error If you don't want FullScreen support, you can safely remove these 2 lines
#endif
}

#if CC_DIRECTOR_MAC_USE_DISPLAY_LINK_THREAD
#define DISPATCH_EVENT(__event__, __selector__) [eventDelegate_ queueEvent:__event__ selector:__selector__];
#else
#define DISPATCH_EVENT(__event__, __selector__)												\
	id obj = eventDelegate_;																\
	[obj performSelector:__selector__														\
			onThread:[(cocos2d::CCDirector*)[CCDirector sharedDirector] runningThread]			\
		  withObject:__event__																\
	   waitUntilDone:NO];
#endif

#pragma mark EAGLView - Mouse events

- (void)mouseDown:(NSEvent *)theEvent
{
	NSPoint event_location = [theEvent locationInWindow];
	NSPoint local_point = [self convertPoint:event_location fromView:nil];
	
	float x = local_point.x;
	float y = [self getHeight] - local_point.y;
	
    int ids[1] = {0};
    float xs[1] = {0.0f};
    float ys[1] = {0.0f};
    
	ids[0] = [theEvent eventNumber];
	xs[0] = x / frameZoomFactor_;
	ys[0] = y / frameZoomFactor_;

	cocos2d::CCDirector::sharedDirector()->getOpenGLView()->handleTouchesBegin(1, ids, xs, ys);
}

- (void)mouseMoved:(NSEvent *)theEvent
{
	DISPATCH_EVENT(theEvent, _cmd);
}

- (void)mouseDragged:(NSEvent *)theEvent
{
	NSPoint event_location = [theEvent locationInWindow];
	NSPoint local_point = [self convertPoint:event_location fromView:nil];
	
	float x = local_point.x;
	float y = [self getHeight] - local_point.y;

    int ids[1] = {0};
    float xs[1] = {0.0f};
    float ys[1] = {0.0f};
    
	ids[0] = [theEvent eventNumber];
	xs[0] = x / frameZoomFactor_;
	ys[0] = y / frameZoomFactor_;

	cocos2d::CCDirector::sharedDirector()->getOpenGLView()->handleTouchesMove(1, ids, xs, ys);
}

- (void)mouseUp:(NSEvent *)theEvent
{
	NSPoint event_location = [theEvent locationInWindow];
	NSPoint local_point = [self convertPoint:event_location fromView:nil];
	
	float x = local_point.x;
	float y = [self getHeight] - local_point.y;

    int ids[1] = {0};
    float xs[1] = {0.0f};
    float ys[1] = {0.0f};
    
	ids[0] = [theEvent eventNumber];
	xs[0] = x / frameZoomFactor_;
	ys[0] = y / frameZoomFactor_;

	cocos2d::CCDirector::sharedDirector()->getOpenGLView()->handleTouchesEnd(1, ids, xs, ys);
}

- (void)rightMouseDown:(NSEvent *)theEvent {
	DISPATCH_EVENT(theEvent, _cmd);

	// pass the event along to the next responder (like your NSWindow subclass)
	[super rightMouseDown:theEvent];
}

- (void)rightMouseDragged:(NSEvent *)theEvent {
	DISPATCH_EVENT(theEvent, _cmd);
	[super rightMouseDragged:theEvent];
}

- (void)rightMouseUp:(NSEvent *)theEvent {
	DISPATCH_EVENT(theEvent, _cmd);
	[super rightMouseUp:theEvent];
}

- (void)otherMouseDown:(NSEvent *)theEvent {
	DISPATCH_EVENT(theEvent, _cmd);
	[super otherMouseDown:theEvent];
}

- (void)otherMouseDragged:(NSEvent *)theEvent {
	DISPATCH_EVENT(theEvent, _cmd);
	[super otherMouseDragged:theEvent];
}

- (void)otherMouseUp:(NSEvent *)theEvent {
	DISPATCH_EVENT(theEvent, _cmd);
	[super otherMouseUp:theEvent];
}

- (void)mouseEntered:(NSEvent *)theEvent {
	DISPATCH_EVENT(theEvent, _cmd);
	[super mouseEntered:theEvent];
}

- (void)mouseExited:(NSEvent *)theEvent {
	DISPATCH_EVENT(theEvent, _cmd);
	[super mouseExited:theEvent];
}

-(void) scrollWheel:(NSEvent *)theEvent {
	DISPATCH_EVENT(theEvent, _cmd);
	[super scrollWheel:theEvent];
}

#pragma mark EAGLView - Key events

-(BOOL) becomeFirstResponder
{
	return YES;
}

-(BOOL) acceptsFirstResponder
{
	return YES;
}

-(BOOL) resignFirstResponder
{
	return YES;
}

- (void)keyDown:(NSEvent *)theEvent
{
	DISPATCH_EVENT(theEvent, _cmd);
	
	// pass the event along to the next responder (like your NSWindow subclass)
	[super keyDown:theEvent];
}

- (void)keyUp:(NSEvent *)theEvent
{
	DISPATCH_EVENT(theEvent, _cmd);

	// pass the event along to the next responder (like your NSWindow subclass)
	[super keyUp:theEvent];
}

- (void)flagsChanged:(NSEvent *)theEvent
{
	DISPATCH_EVENT(theEvent, _cmd);
}

#pragma mark EAGLView - Touch events
- (void)touchesBeganWithEvent:(NSEvent *)theEvent
{
	DISPATCH_EVENT(theEvent, _cmd);
}

- (void)touchesMovedWithEvent:(NSEvent *)theEvent
{
	DISPATCH_EVENT(theEvent, _cmd);
}

- (void)touchesEndedWithEvent:(NSEvent *)theEvent
{
	DISPATCH_EVENT(theEvent, _cmd);
}

- (void)touchesCancelledWithEvent:(NSEvent *)theEvent
{
	DISPATCH_EVENT(theEvent, _cmd);
}
@end
