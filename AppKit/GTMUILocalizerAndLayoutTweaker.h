//
//  GTMUILocalizerAndLayoutTweaker.h
//
//  Copyright 2009 Google Inc.
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

#import <Cocoa/Cocoa.h>
#import "GTMDefines.h"

@class GTMUILocalizer;

// This object will run a GTMUILocalizer on the given object, and then run
// through the object's view heirarchy triggering any Tweakers to do their work.
// (This "double duty" is needed so the work can be done in order during
// awakeFromNib, if it was two objects, the order couldn't be guaranteed.)
@interface GTMUILocalizerAndLayoutTweaker : NSObject {
 @private
  IBOutlet id uiObject_;  // The window or view to process on awakeFromNib
  IBOutlet GTMUILocalizer *localizer_;  // If nil, one will be created
  IBOutlet id localizerOwner_;  // Set if you want the default GTMUILocalizer
}
- (void)applyLocalizer:(GTMUILocalizer *)localizer
            tweakingUI:(id)uiObject;

// This checks to see if |view| implements @selector(sizeToFit) and calls it.
// It then checks the class of |view| and does some fixup for known issues
// where sizeToFit doesn't product a view that meets UI guidelines.
// Returns the amount the view changed in size.
+ (NSSize)sizeToFitView:(NSView *)view;

// If you call sizeToFit on a NSTextField it will try not to word wrap, so it
// can get really wide.  This method will keep the width fixed, but figure out
// how tall the textfield needs to be to fit its text.
// Returns the amount the field changed height.
+ (CGFloat)sizeToFitFixedWidthTextField:(NSTextField *)textField;

@end

// This is a Tweaker that will call sizeToFit on everything within it (that
// supports it).
//
// If the items were all left aligned, they will stay as such and the box will
// resize based on the largest change of any item within it.  If they aren't
// left aligned, they are assumed to be in a row, and it will slide everything
// along as it lays them out to make sure they end up still spaced out and will
// resize itself by the total change to the row.
//
// This Tweaker makes no attempt to deal with changes in an object height.
//
// This Tweaker makes no attempt to deal with its parent's width.
@interface GTMWidthBasedTweaker : NSView {
 @private
  // This outlet is the view that should move by the same amount as this box
  // grows and change its size by the inverse.  i.e.-if a box of NSTextFields,
  // they will stay next to the box of labels and resize so the two boxes
  // continue to use the same total space.
  IBOutlet NSView *viewToSlideAndResize_;
  // This outlet is just like viewToSlideAndResize_ except the view is only
  // slid (ie-its width is not adjusted). i.e.-lets something move along next
  // to this box.
  IBOutlet NSView *viewToSlide_;
  // This outlet is just like viewToSlideAndResize_ except the view is only
  // resized (ie-its position is not adjusted). i.e.-lets something above/below
  // this box stay the same width.  You can set this to be the window, in
  // which case it is resized, but you need to make sure everything is setup
  // to handle that, and using two Tweakers pointed at the window isn't likely
  // to give the results you want.
  IBOutlet id viewToResize_;

  CGFloat widthChange_;
}
// Return the amount we changed our width by on last tweak.
- (CGFloat)changedWidth;
@end
