//
//  GTMLargeTypeWindow.m
//
//  Copyright 2008 Google Inc.
//
//  Licensed under the Apache License, Version 2.0 (the "License"); you may not
//  use this file except in compliance with the License.  You may obtain a copy
//  of the License at
// 
//  http://www.apache.org/licenses/LICENSE-2.0
// 
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
//  WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.  See the
//  License for the specific language governing permissions and limitations under
//  the License.
//

#import <QuartzCore/QuartzCore.h>

#import "GTMLargeTypeWindow.h"
#import "GTMGeometryUtils.h"
#import "GTMNSBezierPath+RoundRect.h"
#import "GTMMethodCheck.h"

// Amount of time to fade the window in or out
const NSTimeInterval kGTMLargeTypeWindowFadeTime = 0.333;

// How far to inset the text from the edge of the window
static const CGFloat kEdgeInset = 16.0;

// Give us an alpha value for our backing window
static const CGFloat kTwoThirdsAlpha = 0.66;

@interface GTMLargeTypeCopyAnimation : NSAnimation
@end

@interface GTMLargeTypeBackgroundView : NSView {
  CIFilter *transition_;
  GTMLargeTypeCopyAnimation *animation_;
}
- (void)animateCopy;
@end

@interface GTMLargeTypeWindow (GTMLargeTypeWindowPrivate)
+ (CGFloat)displayWidth;
- (void)animateWithEffect:(NSString*)effect;
@end

@implementation GTMLargeTypeWindow

- (id)initWithString:(NSString *)string {
  if ([string length] == 0) {
    _GTMDevLog(@"GTMLargeTypeWindow got an empty string");
    [self release];
    return nil;
  }
  CGFloat displayWidth = [[self class] displayWidth];
  NSMutableAttributedString *attrString
    = [[[NSMutableAttributedString alloc] initWithString:string] autorelease];
  
  NSRange fullRange = NSMakeRange(0, [string length]);
  [attrString addAttribute:NSForegroundColorAttributeName 
                     value:[NSColor whiteColor] 
                     range:fullRange];
  
  NSMutableParagraphStyle *style 
  = [[[NSParagraphStyle defaultParagraphStyle] mutableCopy] autorelease];
  [style setAlignment:NSCenterTextAlignment];
  [attrString addAttribute:NSParagraphStyleAttributeName 
                     value:style 
                     range:fullRange];
  
  NSShadow *textShadow = [[[NSShadow alloc] init] autorelease];
  [textShadow setShadowOffset:NSMakeSize( 5, -5 )];
  [textShadow setShadowBlurRadius:10];
  [textShadow setShadowColor:[NSColor colorWithCalibratedWhite:0 
                                                         alpha:kTwoThirdsAlpha]];
  [attrString addAttribute:NSShadowAttributeName 
                     value:textShadow 
                     range:fullRange];
  
  // Try and find a size that fits without iterating too many times.
  // We start going 50 pixels at a time, then 10, then 1
  int size = -26;  // start at 24 (-26 + 50)
  int offsets[] = { 50, 10, 1 };
  NSSize bigSize = NSMakeSize(MAXFLOAT, MAXFLOAT);
  NSStringDrawingOptions options = (NSStringDrawingUsesDeviceMetrics | 
                                    NSStringDrawingOneShot);
  for (size_t i = 0; i < sizeof(offsets) / sizeof(int); ++i) {
    for(size = size + offsets[i]; size >= 24 && size < 300; size += offsets[i]) {
      NSFont *font = [NSFont boldSystemFontOfSize:size] ;
      [attrString addAttribute:NSFontAttributeName 
                         value:font
                         range:fullRange];
      NSRect textSize = [attrString boundingRectWithSize:bigSize
                                                 options:options];
      NSSize maxAdvanceSize = [font maximumAdvancement];
      if (textSize.size.width + maxAdvanceSize.width > displayWidth) {
        size = size - offsets[i];
        break;
      }
    }
  }
  
  // Bounds check our values
  if (size > 300) {
    size = 300;
  } else if (size < 24) {
    size = 24;
  }
  [attrString addAttribute:NSFontAttributeName 
                     value:[NSFont boldSystemFontOfSize:size] 
                     range:fullRange];
  return [self initWithAttributedString:attrString];
}

- (id)initWithAttributedString:(NSAttributedString *)attrString {
  if ([attrString length] == 0) {
    _GTMDevLog(@"GTMLargeTypeWindow got an empty string");
    [self release];
    return nil;
  }
  CGFloat displayWidth =[[self class] displayWidth];
  NSRect frame = NSMakeRect(0, 0, displayWidth, 0);
  NSTextView *textView = [[[NSTextView alloc] initWithFrame:frame] autorelease];
  [textView setEditable:NO];
  [textView setSelectable:NO];
  [textView setDrawsBackground:NO];
  [[textView textStorage] setAttributedString:attrString];
  [textView sizeToFit];
  
  return [self initWithContentView:textView];
}

- (id)initWithImage:(NSImage*)image {
  if (!image) {
    _GTMDevLog(@"GTMLargeTypeWindow got an empty image");
    [self release];
    return nil;
  }
  NSRect rect = GTMNSRectOfSize([image size]);
  NSImageView *imageView 
    = [[[NSImageView alloc] initWithFrame:rect] autorelease];
  [imageView setImage:image];
  return [self initWithContentView:imageView];
}

- (id)initWithContentView:(NSView *)view {
  NSRect bounds = NSZeroRect;
  if (view) {
    bounds = [view bounds];
  }
  if (bounds.size.height <= 0 || bounds.size.width <= 0) {
    _GTMDevLog(@"GTMLargeTypeWindow got an empty view");
    [self release];
    return nil;
  }
  NSRect screenRect = [[NSScreen mainScreen] frame];
  NSRect windowRect = GTMNSAlignRectangles([view frame], 
                                           screenRect,
                                           GTMRectAlignCenter);
  windowRect = NSInsetRect(windowRect, -kEdgeInset, -kEdgeInset);
  windowRect = NSIntegralRect(windowRect);
  NSUInteger mask = NSBorderlessWindowMask | NSNonactivatingPanelMask;
  self = [super initWithContentRect:windowRect
                          styleMask:mask
                            backing:NSBackingStoreBuffered
                              defer:NO];
  if (self) {
    [self setFrame:GTMNSAlignRectangles(windowRect, 
                                        screenRect,
                                        GTMRectAlignCenter)
           display:YES];
    [self setBackgroundColor:[NSColor clearColor]];
    [self setOpaque:NO];
    [self setLevel:NSFloatingWindowLevel];
    [self setHidesOnDeactivate:NO];

    GTMLargeTypeBackgroundView *content 
      = [[[GTMLargeTypeBackgroundView alloc] initWithFrame:NSZeroRect] 
         autorelease];
    [self setHasShadow:YES];
    [self setContentView:content];
    [self setAlphaValue:0];
    [self setIgnoresMouseEvents:YES];
    [view setFrame:GTMNSAlignRectangles([view frame], 
                                        [content frame],
                                        GTMRectAlignCenter)];
    [content addSubview:view];
    [self setInitialFirstResponder:view];
  }
  return self;
}

- (void)copy:(id)sender {
  id firstResponder = [self initialFirstResponder];
  if ([firstResponder respondsToSelector:@selector(textStorage)]) {
    NSPasteboard *pb = [NSPasteboard generalPasteboard];
    [pb declareTypes:[NSArray arrayWithObject:NSStringPboardType] owner:self];
    [pb setString:[[firstResponder textStorage] string]
        forType:NSStringPboardType];
  }
  
  // Give the user some feedback that a copy has occurred
  [(GTMLargeTypeBackgroundView*)[self contentView] animateCopy];
}

- (BOOL)canBecomeKeyWindow { 
  return YES;
}

- (BOOL)performKeyEquivalent:(NSEvent *)theEvent {
  NSString *chars = [theEvent charactersIgnoringModifiers];
  NSUInteger flags = ([theEvent modifierFlags] & 
                      NSDeviceIndependentModifierFlagsMask);
  BOOL isValid = (flags == NSCommandKeyMask) && [chars isEqualToString:@"c"];
  if (isValid) {
    [self copy:self];
  }
  return isValid;
}

- (void)keyDown:(NSEvent *)theEvent {
  [self close];
}

- (void)resignKeyWindow {
  [super resignKeyWindow];
  if([self isVisible]) {
    [self close];
  }
}

- (void)makeKeyAndOrderFront:(id)sender {
  [super makeKeyAndOrderFront:sender];
  [self animateWithEffect:NSViewAnimationFadeInEffect];
}

- (void)orderFront:(id)sender {
  [super orderFront:sender];
  [self animateWithEffect:NSViewAnimationFadeInEffect];
}

- (void)orderOut:(id)sender {
  [self animateWithEffect:NSViewAnimationFadeOutEffect];
  [super orderOut:sender];
}  

+ (CGFloat)displayWidth {
  NSRect screenRect = [[NSScreen mainScreen] frame];
  // This is just a rough calculation to make us fill a good proportion
  // of the main screen.
  return NSWidth( screenRect ) * 11.0 / 12.0 - 2.0 * kEdgeInset;
}

- (void)animateWithEffect:(NSString*)effect {
  NSDictionary *fadeIn = [NSDictionary dictionaryWithObjectsAndKeys:
                          self, NSViewAnimationTargetKey,
                          effect, NSViewAnimationEffectKey,
                          nil];
  NSArray *animation = [NSArray arrayWithObject:fadeIn];
  NSViewAnimation *viewAnim 
    = [[[NSViewAnimation alloc] initWithViewAnimations:animation] autorelease];
  [viewAnim setDuration:kGTMLargeTypeWindowFadeTime];
  [viewAnim setAnimationBlockingMode:NSAnimationBlocking];
  [viewAnim startAnimation];
}
@end

@implementation GTMLargeTypeBackgroundView
GTM_METHOD_CHECK(NSBezierPath, gtm_appendBezierPathWithRoundRect:cornerRadius:);

- (BOOL)isOpaque {
  return NO;
}

- (void)drawRect:(NSRect)rect {
  rect = [self bounds];
  NSBezierPath *roundRect = [NSBezierPath bezierPath];
  CGFloat minRadius = MIN(NSWidth(rect), NSHeight(rect)) * 0.5f;
  
  [roundRect gtm_appendBezierPathWithRoundRect:rect 
                                  cornerRadius:MIN(minRadius, 32)];
  [roundRect addClip];  
  if (transition_) {
    NSNumber *val = [NSNumber numberWithFloat:[animation_ currentValue]];
    [transition_ setValue:val forKey:@"inputTime"];
    CIImage *outputCIImage = [transition_ valueForKey:@"outputImage"];
    [outputCIImage drawInRect:rect 
                     fromRect:rect 
                    operation:NSCompositeSourceOver 
                     fraction:1.0];
  } else {
    [[NSColor colorWithDeviceWhite:0 alpha:kTwoThirdsAlpha] set];
  
    NSRectFill(rect);
  }
}

- (void)animateCopy {
  // This does a photocopy swipe to show folks that their copy has succceeded
  // Store off a copy of our background
  NSRect bounds = [self bounds];
  NSBitmapImageRep *rep = [self bitmapImageRepForCachingDisplayInRect:bounds];
  NSGraphicsContext *context = [NSGraphicsContext graphicsContextWithBitmapImageRep:rep];
  [NSGraphicsContext saveGraphicsState];
  [NSGraphicsContext setCurrentContext:context];
  [self drawRect:bounds];
  [NSGraphicsContext restoreGraphicsState];
  CIVector *extent = [CIVector vectorWithX:bounds.origin.x
                                         Y:bounds.origin.y
                                         Z:bounds.size.width 
                                         W:bounds.size.height];
  CIFilter *transition = [CIFilter filterWithName:@"CICopyMachineTransition"];
  [transition setDefaults];
  [transition setValue:extent
                 forKey:@"inputExtent"];
  CIImage *image = [[CIImage alloc] initWithBitmapImageRep:rep];

  [transition setValue:image forKey:@"inputImage"];
  [transition setValue:image forKey:@"inputTargetImage"];
  [transition setValue:[NSNumber numberWithInt:0]
                 forKey:@"inputTime"];
  [transition valueForKey:@"outputImage"];
  [image release];
  transition_ = [transition retain];  
  animation_ = [[GTMLargeTypeCopyAnimation alloc] initWithDuration:0.5
                                                    animationCurve:NSAnimationLinear];
  [animation_ setFrameRate:0.0f];
  [animation_ setDelegate:self];
  [animation_ setAnimationBlockingMode:NSAnimationBlocking];
  [animation_ startAnimation];
}
  
- (void)animationDidEnd:(NSAnimation*)animation {
  [animation_ release];
  animation_ = nil;
  [transition_ release];
  transition_ = nil;
  [self display];
}

- (float)animation:(NSAnimation*)animation 
  valueForProgress:(NSAnimationProgress)progress {
  // This gives us half the copy animation, so we don't swing back
  // Don't want too much gratuitous effect
  // 0.6 is required by experimentation. 0.5 doesn't do it
  return progress * 0.6f;
}
@end

@implementation GTMLargeTypeCopyAnimation
- (void)setCurrentProgress:(NSAnimationProgress)progress {
  [super setCurrentProgress:progress];
  [[self delegate] display];
}
@end
