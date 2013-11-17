//
//  OTPStringEncoding.h
//
//  Copyright 2010-2011 Google Inc.
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

// A generic class for arbitrary base-2 to 128 string encoding and decoding.
@interface OTPStringEncoding : NSObject

+ (id)base32CaseInsensitiveStringEncoding;

// Initialize a new OTPStringEncoding object with the string.
//
// The length of the string must be a power of 2, at least 2 and at most 128.
// Only 7-bit ASCII characters are permitted in the string.
//
// These characters are the canonical set emitted during encoding.
// If the characters have alternatives (e.g. case, easily transposed) then use
// addDecodeSynonyms: to configure them.
- (id)initWithString:(NSString *)string;

// Add decoding synonyms as specified in the synonyms argument.
//
// It should be a sequence of one previously reverse mapped character,
// followed by one or more non-reverse mapped character synonyms.
// Only 7-bit ASCII characters are permitted in the string.
//
// e.g. If a GTMStringEncoder object has already been initialised with a set
// of characters excluding I, L and O (to avoid confusion with digits) and you
// want to accept them as digits you can call addDecodeSynonyms:@"0oO1iIlL".
- (void)addDecodeSynonyms:(NSString *)synonyms;

// A sequence of characters to ignore if they occur during encoding.
// Only 7-bit ASCII characters are permitted in the string.
- (void)ignoreCharacters:(NSString *)chars;

// Encode a raw binary buffer to a 7-bit ASCII string.
- (NSString *)encode:(NSData *)data;

// Decode a 7-bit ASCII string to a raw binary buffer.
- (NSData *)decode:(NSString *)string;

@end
