//
//  GTMGarbageCollection.h
//
//  Copyright 2007-2008 Google Inc.
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

#import <Foundation/Foundation.h>

#import "GTMDefines.h"

// This allows us to easily move our code from GC to non GC.
// They are no-ops unless we are require Leopard or above.
// See 
// http://developer.apple.com/documentation/Cocoa/Conceptual/GarbageCollection/index.html
// and
// http://developer.apple.com/documentation/Cocoa/Conceptual/GarbageCollection/Articles/gcCoreFoundation.html#//apple_ref/doc/uid/TP40006687-SW1
// for details.

#if (MAC_OS_X_VERSION_MIN_REQUIRED >= 1050) && !GTM_IPHONE_SDK
// General use would be to call this through GTMCFAutorelease
// but there may be a reason the you want to make something collectable
// but not autoreleased, especially in pure GC code where you don't
// want to bother with the nop autorelease.
FOUNDATION_STATIC_INLINE id GTMNSMakeCollectable(CFTypeRef cf) { 
  return NSMakeCollectable(cf); 
}

// GTMNSMakeUncollectable is for global maps, etc. that we don't
// want released ever. You should still retain these in non-gc code.
FOUNDATION_STATIC_INLINE void GTMNSMakeUncollectable(id object) {
  [[NSGarbageCollector defaultCollector] disableCollectorForPointer:object];
}

// Hopefully no code really needs this, but GTMIsGarbageCollectionEnabled is
// a common way to check at runtime if GC is on.
// There are some places where GC doesn't work w/ things w/in Apple's
// frameworks, so this is here so GTM unittests and detect it, and not run
// individual tests to work around bugs in Apple's frameworks.
FOUNDATION_STATIC_INLINE BOOL GTMIsGarbageCollectionEnabled(void) {
  return ([NSGarbageCollector defaultCollector] != nil);
}

#else

FOUNDATION_STATIC_INLINE id GTMNSMakeCollectable(CFTypeRef cf) { 
  // NSMakeCollectable handles NULLs just fine and returns nil as expected.
  return (id)cf;
}

FOUNDATION_STATIC_INLINE void GTMNSMakeUncollectable(id object) {
}

FOUNDATION_STATIC_INLINE BOOL GTMIsGarbageCollectionEnabled(void) {
  return NO;
}

#endif

// GTMCFAutorelease makes a CF object collectable in GC mode, or adds it 
// to the autorelease pool in non-GC mode. Either way it is taken care
// of.
FOUNDATION_STATIC_INLINE id GTMCFAutorelease(CFTypeRef cf) {
  return [GTMNSMakeCollectable(cf) autorelease];
}

