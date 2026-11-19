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
#include "CCEGLView.h"
#include "EAGLView.h"
#include "CCDirectorCaller.h"
#include "CCSet.h"
#include "CCTouch.h"
#include "CCTouchDispatcher.h"

NS_CC_BEGIN

static NSSize backingScale(EAGLView *view)
{
    NSRect bounds = [view bounds];
    NSRect backingBounds = [view convertRectToBacking:bounds];
    return NSMakeSize(bounds.size.width ? backingBounds.size.width / bounds.size.width : 1.0f,
                      bounds.size.height ? backingBounds.size.height / bounds.size.height : 1.0f);
}

CCEGLView* CCEGLView::s_sharedView = NULL;

CCEGLView* CCEGLView::sharedOpenGLView(void)
{
    if (!s_sharedView)
    {
        s_sharedView = new CCEGLView();
    }
    return s_sharedView;
}

CCEGLView::CCEGLView(void)
{
}

CCEGLView::~CCEGLView(void)
{
    CCLOG("cocos2d: deallocing CCEGLView %p", this);
    s_sharedView = NULL;
}

bool CCEGLView::isOpenGLReady(void)
{
    return [EAGLView sharedEGLView] != NULL;
}

bool CCEGLView::setContentScaleFactor(float contentScaleFactor)
{
    return false;
}

void CCEGLView::end(void)
{
    [[CCDirectorCaller sharedDirectorCaller] end];
    
    // destroy EAGLView
    [[EAGLView sharedEGLView] removeFromSuperview];
    
    delete this;
}

void CCEGLView::swapBuffers()
{
	[[EAGLView sharedEGLView] swapBuffers];
}

void CCEGLView::setIMEKeyboardState(bool bOpen)
{
    if (bOpen)
    {
        [[EAGLView sharedEGLView] becomeFirstResponder];
    }
    else
    {
        [[EAGLView sharedEGLView] resignFirstResponder];
    }
}

void CCEGLView::setViewPortInPoints(float x , float y , float w , float h)
{
    EAGLView *view = [EAGLView sharedEGLView];
    float frameZoomFactor = [view frameZoomFactor];
    NSSize scale = backingScale(view);

    // OpenGL viewports use backing pixels, while the director uses window points.
    glViewport((GLint)((x * m_fScaleX + m_obViewPortRect.origin.x) * frameZoomFactor * scale.width),
               (GLint)((y * m_fScaleY + m_obViewPortRect.origin.y) * frameZoomFactor * scale.height),
               (GLsizei)(w * m_fScaleX * frameZoomFactor * scale.width),
               (GLsizei)(h * m_fScaleY * frameZoomFactor * scale.height));
}

void CCEGLView::setScissorInPoints(float x , float y , float w , float h)
{
    EAGLView *view = [EAGLView sharedEGLView];
    float frameZoomFactor = [view frameZoomFactor];
    NSSize scale = backingScale(view);

    glScissor((GLint)((x * m_fScaleX + m_obViewPortRect.origin.x) * frameZoomFactor * scale.width),
              (GLint)((y * m_fScaleY + m_obViewPortRect.origin.y) * frameZoomFactor * scale.height),
              (GLsizei)(w * m_fScaleX * frameZoomFactor * scale.width),
              (GLsizei)(h * m_fScaleY * frameZoomFactor * scale.height));
}

CCRect CCEGLView::getScissorRect()
{
    EAGLView *view = [EAGLView sharedEGLView];
    float frameZoomFactor = [view frameZoomFactor];
    NSSize scale = backingScale(view);
    GLint box[4];
    glGetIntegerv(GL_SCISSOR_BOX, box);

    float scaleX = m_fScaleX * frameZoomFactor * scale.width;
    float scaleY = m_fScaleY * frameZoomFactor * scale.height;
    return CCRectMake((box[0] / (frameZoomFactor * scale.width) - m_obViewPortRect.origin.x) / m_fScaleX,
                      (box[1] / (frameZoomFactor * scale.height) - m_obViewPortRect.origin.y) / m_fScaleY,
                      box[2] / scaleX,
                      box[3] / scaleY);
}

void CCEGLView::setMultiTouchMask(bool mask)
{
	//EAGLView *glView = [EAGLView sharedEGLView];
	//glView.multipleTouchEnabled = mask ? YES : NO;
}

NS_CC_END // end of namespace cocos2d;
