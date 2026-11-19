// Debug-only integration fixture. Invoked explicitly with --verify-fbo <directory>.
// Uses the same director, presentation path and snapshot method as the application.
class FboDetailFixture : public cocos2d::CCNode {
public:
    virtual void draw() {
        cocos2d::ccDrawColor4B(255, 255, 255, 255);
        for (int x = 12; x < 220; x += 3)
            cocos2d::ccDrawLine(ccp(x, 24), ccp(x, 100));
        cocos2d::ccDrawColor4B(255, 100, 40, 255);
        cocos2d::ccDrawLine(ccp(12, 110), ccp(450, 220));
    }
};

static BOOL verifySceneFramebuffer(EAGLView *view, NSString *directory)
{
    using namespace cocos2d;
    CCDirector *director = CCDirector::sharedDirector();
    director->stopAnimation();
    director->setDisplayStats(false);
    director->pause();
    [view lockOpenGLContext];
    CCScene *scene = CCScene::create();
    scene->addChild(CCLayerColor::create(ccc4(24, 35, 48, 255)));
    FboDetailFixture *detail = new FboDetailFixture();
    scene->addChild(detail);
    detail->release();
    CCLabelBMFont *label = CCLabelBMFont::create("Original pixels 0123456789 / AaBb", "fonts/arial-26-en-ru.fnt");
    label->setScale(0.5f);
    label->setPosition(ccp(240, 285));
    scene->addChild(label);
    CCSprite *sprite = CCSprite::create("Images/grossini.png");
    sprite->setPosition(ccp(360, 140));
    scene->addChild(sprite);
    // Exercise a nested framebuffer and its restoration to the scene target.
    CCRenderTexture *nested = CCRenderTexture::create(96, 64);
    nested->beginWithClear(0.1f, 0.7f, 0.25f, 1.0f);
    CCSprite *nestedSprite = CCSprite::create("Images/grossini.png");
    nestedSprite->setPosition(ccp(24, 16));
    nestedSprite->visit();
    nested->end();
    nested->setPosition(ccp(270, 170));
    scene->addChild(nested);
    director->replaceScene(scene);
    director->drawScene();
    [view unlockOpenGLContext];

    NSError *error = nil;
    if (![[NSFileManager defaultManager] createDirectoryAtPath:directory
        withIntermediateDirectories:YES attributes:nil error:&error]) return NO;
    NSData *reference = nil;
    BOOL passed = YES;
    [view lockOpenGLContext];
    passed = [view setScenePixelSize:NSMakeSize(640, 480)] && passed;
    NSBitmapImageRep *resized = [view sceneSnapshot];
    passed = resized && [resized pixelsWide] == 640 && [resized pixelsHigh] == 480 && passed;
    passed = [view setScenePixelSize:NSZeroSize] && ![view usesSceneFramebuffer] && ![view sceneSnapshot] && passed;
    passed = [view setScenePixelSize:NSMakeSize(960, 640)] && passed;
    [view unlockOpenGLContext];
    int zooms[] = {100, 50, 25, 100};
    for (int i = 0; i < 4; ++i) {
        [view setFrameZoomFactor:zooms[i] / 100.0f];
        [view lockOpenGLContext];
        director->drawScene();
        CCEGLView *egl = CCEGLView::sharedOpenGLView();
        egl->setScissorInPoints(10, 20, 30, 40);
        CCRect scissor = egl->getScissorRect();
        passed = passed && fabsf(scissor.origin.x - 10) < 0.01f &&
            fabsf(scissor.origin.y - 20) < 0.01f && fabsf(scissor.size.width - 30) < 0.01f &&
            fabsf(scissor.size.height - 40) < 0.01f;
        NSBitmapImageRep *image = [[view sceneSnapshot] retain];
        GLint readBefore, drawBefore;
        glGetIntegerv(GL_READ_FRAMEBUFFER_BINDING, &readBefore);
        glGetIntegerv(GL_DRAW_FRAMEBUFFER_BINDING, &drawBefore);
        // Snapshot must preserve separate read/draw framebuffer bindings.
        [view sceneSnapshot];
        GLint readAfter, drawAfter;
        glGetIntegerv(GL_READ_FRAMEBUFFER_BINDING, &readAfter);
        glGetIntegerv(GL_DRAW_FRAMEBUFFER_BINDING, &drawAfter);
        passed = passed && readBefore == readAfter && drawBefore == drawAfter;
        passed = passed && ![view setScenePixelSize:NSMakeSize(5000, 640)] && [view usesSceneFramebuffer];
        [view unlockOpenGLContext];
        if (!image || [image pixelsWide] != 960 || [image pixelsHigh] != 640) passed = NO;
        NSData *pixels = image ? [NSData dataWithBytes:[image bitmapData]
            length:[image bytesPerRow] * [image pixelsHigh]] : nil;
        if (i == 0) reference = [pixels retain];
        else if (![reference isEqualToData:pixels]) passed = NO;
        NSString *path = [directory stringByAppendingPathComponent:
            [NSString stringWithFormat:@"scene-%d-%d.png", zooms[i], i]];
        NSData *png = [image representationUsingType:NSPNGFileType properties:[NSDictionary dictionary]];
        if (!png || ![png writeToFile:path atomically:YES]) passed = NO;
        [image release];
    }
    [reference release];
    NSString *result = passed ? @"PASS: four 960x640 snapshots have identical RGBA pixels; GL bindings preserved; invalid size rejected\n" : @"FAIL\n";
    [result writeToFile:[directory stringByAppendingPathComponent:@"result.txt"]
        atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    NSLog(@"FBO verification: %@", result);
    return passed;
}
