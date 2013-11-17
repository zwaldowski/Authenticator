//
//  OTPStringEncoding.m
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

#import "OTPStringEncoding.h"
#import "OTPDefines.h"

enum {
  kUnknownChar = -1,
  kPaddingChar = -2,
  kIgnoreChar = -3
};

@implementation OTPStringEncoding {
@private
    NSData *charMapData_;
    char *charMap_;
    int reverseCharMap_[128];
    int shift_;
    int mask_;
    int padLen_;
}

+ (id)base32CaseInsensitiveStringEncoding
{
    OTPStringEncoding *coder = [[OTPStringEncoding alloc] initWithString:@"ABCDEFGHIJKLMNOPQRSTUVWXYZ234567"];
    [coder addDecodeSynonyms:@"AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz"];
    [coder ignoreCharacters:@" -"];
    return [coder autorelease];
}

static inline __attribute__((always_inline)) int lcm(int a, int b) {
  for (int aa = a, bb = b;;) {
    if (aa == bb)
      return aa;
    else if (aa < bb)
      aa += a;
    else
      bb += b;
  }
}

- (id)initWithString:(NSString *)string {
  if ((self = [super init])) {
    charMapData_ = [[string dataUsingEncoding:NSASCIIStringEncoding] retain];
    if (!charMapData_) {
      OTPDevLog(@"Unable to convert string to ASCII");
      [self release];
      return nil;
    }
    charMap_ = (char *)[charMapData_ bytes];
    NSUInteger length = [charMapData_ length];
    if (length < 2 || length > 128 || length & (length - 1)) {
      OTPDevLog(@"Length not a power of 2 between 2 and 128");
      [self release];
      return nil;
    }

    memset(reverseCharMap_, kUnknownChar, sizeof(reverseCharMap_));
    for (unsigned int i = 0; i < length; i++) {
      if (reverseCharMap_[(int)charMap_[i]] != kUnknownChar) {
        OTPDevLog(@"Duplicate character at pos %d", i);
        [self release];
        return nil;
      }
      reverseCharMap_[(int)charMap_[i]] = i;
    }

    for (NSUInteger i = 1; i < length; i <<= 1)
      shift_++;
    mask_ = (1 << shift_) - 1;
    padLen_ = lcm(8, shift_) / shift_;
  }
  return self;
}

- (void)dealloc {
  [charMapData_ release];
  [super dealloc];
}

- (NSString *)description {
  // TODO(iwade) track synonyms
  return [NSString stringWithFormat:@"<Base%d StringEncoder: %@>",
          1 << shift_, charMapData_];
}

- (void)addDecodeSynonyms:(NSString *)synonyms {
  const char *buf = [synonyms UTF8String];
  int val = kUnknownChar;
  while (*buf) {
    int c = *buf++;
    if (reverseCharMap_[c] == kUnknownChar) {
      reverseCharMap_[c] = val;
    } else {
      val = reverseCharMap_[c];
    }
  }
}

- (void)ignoreCharacters:(NSString *)chars {
  const char *buf = [chars UTF8String];
  while (*buf) {
    int c = *buf++;
    NSAssert(reverseCharMap_[c] == kUnknownChar,
             @"Character already mapped");
    reverseCharMap_[c] = kIgnoreChar;
  }
}

- (NSString *)encode:(NSData *)inData {
  NSUInteger inLen = [inData length];
  if (inLen <= 0) {
    OTPDevLog(@"Empty input");
    return @"";
  }
  unsigned char *inBuf = (unsigned char *)[inData bytes];
  NSUInteger inPos = 0;

  NSUInteger outLen = (inLen * 8 + shift_ - 1) / shift_;
  NSMutableData *outData = [NSMutableData dataWithLength:outLen];
  unsigned char *outBuf = (unsigned char *)[outData mutableBytes];
  NSUInteger outPos = 0;

  int buffer = inBuf[inPos++];
  int bitsLeft = 8;
  while (bitsLeft > 0 || inPos < inLen) {
    if (bitsLeft < shift_) {
      if (inPos < inLen) {
        buffer <<= 8;
        buffer |= (inBuf[inPos++] & 0xff);
        bitsLeft += 8;
      } else {
        int pad = shift_ - bitsLeft;
        buffer <<= pad;
        bitsLeft += pad;
      }
    }
    int idx = (buffer >> (bitsLeft - shift_)) & mask_;
    bitsLeft -= shift_;
    outBuf[outPos++] = charMap_[idx];
  }

  NSAssert(outPos == outLen, @"Underflowed output buffer");
  [outData setLength:outPos];

  return [[[NSString alloc] initWithData:outData encoding:NSUTF8StringEncoding] autorelease];
}

- (NSData *)decode:(NSString *)inString {
  const char *inBuf = [inString UTF8String];
  if (!inBuf) {
    OTPDevLog(@"unable to convert buffer to ASCII");
    return nil;
  }
  NSUInteger inLen = strlen(inBuf);

  NSUInteger outLen = inLen * shift_ / 8;
  NSMutableData *outData = [NSMutableData dataWithLength:outLen];
  unsigned char *outBuf = (unsigned char *)[outData mutableBytes];
  NSUInteger outPos = 0;

  int buffer = 0;
  int bitsLeft = 0;
  BOOL expectPad = NO;
  for (NSUInteger i = 0; i < inLen; i++) {
    int val = reverseCharMap_[(int)inBuf[i]];
    switch (val) {
      case kIgnoreChar:
        break;
      case kPaddingChar:
        expectPad = YES;
        break;
      case kUnknownChar:
        OTPDevLog(@"Unexpected data in input pos %lu", (unsigned long)i);
        return nil;
      default:
        if (expectPad) {
          OTPDevLog(@"Expected further padding characters");
          return nil;
        }
        buffer <<= shift_;
        buffer |= val & mask_;
        bitsLeft += shift_;
        if (bitsLeft >= 8) {
          outBuf[outPos++] = (unsigned char)(buffer >> (bitsLeft - 8));
          bitsLeft -= 8;
        }
        break;
    }
  }

  if (bitsLeft && buffer & ((1 << bitsLeft) - 1)) {
    OTPDevLog(@"Incomplete trailing data");
    return nil;
  }

  // Shorten buffer if needed due to padding chars
  NSAssert(outPos <= outLen, @"Overflowed buffer");
  [outData setLength:outPos];

  return outData;
}

@end
