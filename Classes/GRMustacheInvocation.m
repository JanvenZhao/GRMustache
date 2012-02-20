// The MIT License
// 
// Copyright (c) 2012 Gwendal Roué
// 
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
// 
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
// 
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import "GRMustacheInvocation_private.h"
#import "GRMustacheContext_private.h"

typedef void (*GRMustacheInvocationFunction)(NSString *key, BOOL *inOutScoped, GRMustacheContext **inOutContext);

static void invokeImplicitIteratorKey(NSString *key, BOOL *inOutScoped, GRMustacheContext **inOutContext) {
    *inOutScoped = YES;
}

static void invokePopKey(NSString *key, BOOL *inOutScoped, GRMustacheContext **inOutContext) {
    *inOutScoped = NO;
    *inOutContext = (*inOutContext).parent;
}

static void invokeOtherKey(NSString *key, BOOL *inOutScoped, GRMustacheContext **inOutContext) {
    *inOutContext = [*inOutContext contextForKey:key scoped:*inOutScoped];
    *inOutScoped = YES;
}

@interface GRMustacheInvocation()
- (GRMustacheInvocationFunction)invocationFunctionForKey:(NSString *)key;
@end

@interface GRMustacheInvocationKey:GRMustacheInvocation {
    GRMustacheInvocationFunction _invocationFunction;
    NSString *_key;
}
- (id)initWithKey:(NSArray *)keys;
@end

@interface GRMustacheInvocationKeyPath:GRMustacheInvocation {
    GRMustacheInvocationFunction *_invocationFunctions;
    NSArray *_keys;
}
- (id)initWithKeys:(NSArray *)keys;
@end

@implementation GRMustacheInvocation

+ (id)invocationWithKeys:(NSArray *)keys
{
    if (keys.count > 1) {
        return [[[GRMustacheInvocationKeyPath alloc] initWithKeys:keys] autorelease];
    } else {
        return [[[GRMustacheInvocationKey alloc] initWithKey:[keys objectAtIndex:0]] autorelease];
    }
}

- (GRMustacheInvocationFunction)invocationFunctionForKey:(NSString *)key
{
    if ([key isEqualToString:@"."] || [key isEqualToString:@"this"]) {
        return invokeImplicitIteratorKey;
    } else if ([key isEqualToString:@".."]) {
        return invokePopKey;
    } else {
        return invokeOtherKey;
    }
}

- (id)invokeWithContext:(GRMustacheContext *)context
{
    // abstract method
    return nil;
}

@end

@implementation GRMustacheInvocationKey

- (void)dealloc
{
    [_key release];
    [super dealloc];
}

- (id)initWithKey:(NSString *)key
{
    self = [super init];
    if (self) {
        _key = [key retain];
        _invocationFunction = [self invocationFunctionForKey:key];
    }
    return self;
}

- (id)invokeWithContext:(GRMustacheContext *)context
{
    BOOL scoped = NO;
    _invocationFunction(_key, &scoped, &context);
    return context.object;
}

@end


@implementation GRMustacheInvocationKeyPath

- (void)dealloc
{
    [_keys release];
    free(_invocationFunctions);
    [super dealloc];
}

- (id)initWithKeys:(NSArray *)keys
{
    self = [super init];
    if (self) {
        _keys = [keys retain];
        GRMustacheInvocationFunction *f = _invocationFunctions = malloc(keys.count*sizeof(GRMustacheInvocationFunction));
        for (NSString *key in _keys) {
            *(f++) = [self invocationFunctionForKey:key];
        }
    }
    return self;
}

- (id)invokeWithContext:(GRMustacheContext *)context
{
    BOOL scoped = NO;
    
    GRMustacheInvocationFunction *f = _invocationFunctions;
    for (NSString *key in _keys) {
        (*(f++))(key, &scoped, &context);
        if (!context) return nil;
    }
    
    return context.object;
}

@end

