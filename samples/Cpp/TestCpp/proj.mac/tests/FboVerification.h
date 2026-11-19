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

class FboNestedFixture : public cocos2d::CCNode {
    cocos2d::CCRenderTexture *target_;
    cocos2d::CCSprite *sprite_;
public:
    bool restored;
    FboNestedFixture() : restored(true) {
        target_ = cocos2d::CCRenderTexture::create(96, 64);
        target_->retain();
        target_->setPosition(ccp(270, 170));
        sprite_ = cocos2d::CCSprite::create("Images/grossini.png");
        sprite_->retain();
        sprite_->setPosition(ccp(24, 16));
    }
    virtual ~FboNestedFixture() { target_->release(); sprite_->release(); }
    virtual void draw() {
        GLint before, after;
        glGetIntegerv(GL_FRAMEBUFFER_BINDING, &before);
        target_->beginWithClear(0.1f, 0.7f, 0.25f, 1.0f);
        sprite_->visit();
        target_->end();
        glGetIntegerv(GL_FRAMEBUFFER_BINDING, &after);
        restored = restored && before != 0 && before == after;
        target_->visit();
        // This marker must reach the scene framebuffer after the nested pass.
        cocos2d::ccDrawColor4B(255, 255, 0, 255);
        cocos2d::ccDrawLine(ccp(240, 230), ccp(300, 230));
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
    FboNestedFixture *nested = new FboNestedFixture();
    scene->addChild(nested);
    nested->release();
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
        passed = passed && nested->restored;
        CCEGLView *egl = CCEGLView::sharedOpenGLView();
        egl->setScissorInPoints(10, 20, 30, 40);
        CCRect scissor = egl->getScissorRect();
        passed = passed && fabsf(scissor.origin.x - 10) < 0.01f &&
            fabsf(scissor.origin.y - 20) < 0.01f && fabsf(scissor.size.width - 30) < 0.01f &&
            fabsf(scissor.size.height - 40) < 0.01f;
        // Inject an unrelated scene error; it must not reject a valid snapshot.
        glEnable(0xFFFFFFFF);
        NSBitmapImageRep *image = [[view sceneSnapshot] retain];
        passed = passed && image && glGetError() == GL_NO_ERROR;
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
        BOOL markerVisible = NO;
        if (image) {
            for (int y = 178; y <= 182; ++y) {
                for (int x = 480; x < 600; ++x) {
                    const unsigned char *pixel = [image bitmapData] + y * [image bytesPerRow] + x * 4;
                    if (pixel[0] > 240 && pixel[1] > 240 && pixel[2] < 15) markerVisible = YES;
                }
            }
        }
        passed = passed && markerVisible;
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
