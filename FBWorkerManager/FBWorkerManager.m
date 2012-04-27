//
// Copyright (c) 2011 Five-technology Co.,Ltd.
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
//

#import "FBWorkerManager.h"

#define FBWORKERMANAGER_TIMEINTERVAL_FOR_CHECK  1.0
#define FBWORKERMANAGER_TIMOUT                  30
#define FBWORKERMANAGER_MAX_WORKERS             1

#pragma mark -
@interface FBWorkerManager()
@property (assign) FBWorkerManagerState state;
@property (nonatomic, assign) NSTimeInterval interval;
@property (nonatomic, retain) NSTimer* timer;
@property (nonatomic, retain) NSMutableSet* workerSet;
@property (nonatomic, assign) BOOL isAsynchronous;
@end


#pragma mark -
@implementation FBWorkerManager
@synthesize delegate = delegate_;
@synthesize maxWorkers = maxWorkers_;
@synthesize interval = interval_;
@synthesize timeout = timeout_;
@synthesize state = state_;
@synthesize workerSource = workerSource_;
@synthesize timer = timer_;
@synthesize workerSet = workerSet_;
@synthesize isAsynchronous = isAsynchronous_;

#pragma mark -
#pragma mark Privates

- (BOOL)_checkMaxWorkers
{
    if (self.maxWorkers == 0) {
        return YES;
    }
    
    NSUInteger count = 0;
    for (id <FBWorker> worker in self.workerSet) {
        if ([worker workerState] == FBWorkerStateExecuting) {
            count++;
        }
    }
    return (count < self.maxWorkers);
}

- (BOOL)_setWorker:(id <FBWorker>)worker workerState:(FBWorkerState)workerState
{
    BOOL result = NO;

    switch (workerState) {
        case FBWorkerStateWaiting: // resume
            result = (worker.workerState == FBWorkerStateSuspending);
            break;
            
        case FBWorkerStateExecuting:
            result = (worker.workerState == FBWorkerStateWaiting);
            break;
            
        case FBWorkerStateSuspending:
            result = (worker.workerState == FBWorkerStateExecuting ||
                      worker.workerState == FBWorkerStateWaiting);
            break;
            
        case FBWorkerStateCompleted:
            result = (worker.workerState == FBWorkerStateExecuting);
            break;
            
        case FBWorkerStateCanceled:
            result = (worker.workerState != FBWorkerStateCompleted &&
                      worker.workerState != FBWorkerStateCanceled);
            break;
        case FBWorkerStateTimeout:
            result = (worker.workerState == FBWorkerStateExecuting);
            break;
    }

    if (!result) {
        return NO;
    }
    
    worker.workerState = workerState;

    switch (workerState) {
        case FBWorkerStateWaiting: // resume
            if ([worker respondsToSelector:@selector(resumeWithWorkerManager:)]) {
                [worker resumeWithWorkerManager:self];
            }
            break;
            
        case FBWorkerStateExecuting:
            break;
            
        case FBWorkerStateSuspending:
            if ([worker respondsToSelector:@selector(suspendWithWorkerManager:)]) {
                [worker suspendWithWorkerManager:self];
            }
            break;
            
        case FBWorkerStateCompleted:
            if ([self.delegate respondsToSelector:@selector(didFinishWorkerManager:worker:)]) {
                [self.delegate didFinishWorkerManager:self worker:worker];
            }
            [self.workerSet removeObject:worker];
            break;
            
        case FBWorkerStateCanceled:
            if ([worker respondsToSelector:@selector(cancelWithWorkerManager:)]) {
                [worker cancelWithWorkerManager:self];
            }
            if ([self.delegate respondsToSelector:@selector(didFinishWorkerManager:worker:)]) {
                [self.delegate didFinishWorkerManager:self worker:worker];
            }
            [self.workerSet removeObject:worker];
            break;

        case FBWorkerStateTimeout:
            if ([worker respondsToSelector:@selector(timeoutWithWorkerManager:)]) {
                [worker timeoutWithWorkerManager:self];
            }
            if ([self.delegate respondsToSelector:@selector(didFinishWorkerManager:worker:)]) {
                [self.delegate didFinishWorkerManager:self worker:worker];
            }
            [self.workerSet removeObject:worker];
            break;
    }
    return YES;
}

- (void)_updateWorker:(id <FBWorker>)worker
{
    if ([self.delegate respondsToSelector:@selector(didUpdateWorkerManager:worker:)]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate didUpdateWorkerManager:self worker:worker];
        });
    }
}

- (void)_runWorker
{
    id <FBWorker> worker;

    while ((worker = [self.workerSource nextWorkerWithWorkerManager:self])) {
        [self _setWorker:worker workerState:FBWorkerStateExecuting];
        [self.workerSet addObject:worker];

        if ([self.delegate respondsToSelector:@selector(willBeginWorkerManager:worker:)]) {
            [self.delegate willBeginWorkerManager:self worker:worker];
        }

        if (self.isAsynchronous) {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{

                if ([worker executeWithWorkerManager:self]) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self _setWorker:worker workerState:FBWorkerStateCompleted];                
                    });
                }
            });
        } else {
            if ([worker executeWithWorkerManager:self]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self _setWorker:worker workerState:FBWorkerStateCompleted];                
                });
            }
        }
        
        if (![self _checkMaxWorkers]) {
            break;
        }
    }
}

- (void)_updateElapse
{
    for (id <FBWorker> worker in [NSSet setWithSet:self.workerSet]) {
        if (worker.workerState == FBWorkerStateExecuting) {
            worker.workerElapse += self.interval;
            if (self.timeout && worker.workerElapse > self.timeout) {
                [self _setWorker:worker workerState:FBWorkerStateTimeout];
                if ([worker respondsToSelector:@selector(timeoutWithWorkerManager:)]) {
                    [worker timeoutWithWorkerManager:self];
                }
            }
        }
    }
}

- (void)_check:(NSTimer*)timer
{
    if (self.state != FBWorkerManagerStateRunning) {
        return;
    }

    [self _updateElapse];

    if ([self.delegate respondsToSelector:@selector(canWorkerManagerRun)]) {
        if (![self.delegate canWorkerManagerRun]) {
            return;
        }
    }
    
    if ([self _checkMaxWorkers]) {
        [self _runWorker];
    }
}


#pragma mark -
#pragma mark Basics

- (id)initWithAsynchronous:(BOOL)asynchronous
{
    self = [super init];
    if (self) {
        self.interval = FBWORKERMANAGER_TIMEINTERVAL_FOR_CHECK;
        self.timeout = FBWORKERMANAGER_TIMOUT;
        self.state = FBWorkerManagerStateStopping;
        self.maxWorkers = FBWORKERMANAGER_MAX_WORKERS;
        self.workerSet = [NSMutableSet set];
        self.isAsynchronous = asynchronous;
    }
    
    return self;
}

- (void)dealloc {
    if ([self.timer isValid]) {
        [self.timer invalidate];
    }
    self.timer = nil;
    self.workerSource = nil;
    [super dealloc];
}

#pragma mark -
#pragma mark Properties
- (BOOL)isRunning
{
    return (self.state == FBWorkerManagerStateRunning);
}


#pragma mark -
#pragma mark API (General)

+ (FBWorkerManager*)workerManagerWithAnsynchronous:(BOOL)asynchronous
{
    return [[[self alloc] initWithAsynchronous:asynchronous] autorelease];
}

- (BOOL)start
{
    if (self.state != FBWorkerManagerStateStopping) {
        return NO;
    }
    self.state = FBWorkerManagerStateRunning;
    
    [self _check:nil];
    self.timer = [NSTimer scheduledTimerWithTimeInterval:self.interval
                                                  target:self
                                                selector:@selector(_check:)
                                                userInfo:nil
                                                 repeats:YES];
    return YES;
}

- (BOOL)stop
{
    if (self.state != FBWorkerManagerStateRunning) {
        return NO;
    }
    self.state = FBWorkerManagerStateStopping;
    
    if ([self.timer isValid]) {
        [self.timer invalidate];
    }
    self.timer = nil;   
    return YES;
}


static UIBackgroundTaskIdentifier backgroundTaskIdentifer_;
static BOOL backgroundTaskEnabled_ = NO;

+ (void)_willResignActive:(NSNotification*)notification
{
    UIApplication* app = [UIApplication sharedApplication];
    
    NSAssert(backgroundTaskIdentifer_ == UIBackgroundTaskInvalid, @"UIBackgroundTaskInvalid");
    
    backgroundTaskIdentifer_ = [app beginBackgroundTaskWithExpirationHandler:^{
        
        // expire !
        dispatch_async(dispatch_get_main_queue(), ^{
            if (backgroundTaskIdentifer_ != UIBackgroundTaskInvalid) {
                [app endBackgroundTask:backgroundTaskIdentifer_];
                backgroundTaskIdentifer_ = UIBackgroundTaskInvalid;
            }
        });
    }];       
}

+ (void)_didBecomeActive:(NSNotification*)notification
{
    UIApplication* app = [UIApplication sharedApplication];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if (backgroundTaskIdentifer_ != UIBackgroundTaskInvalid) {
            [app endBackgroundTask:backgroundTaskIdentifer_];
            backgroundTaskIdentifer_ = UIBackgroundTaskInvalid;
        }
    });
    /*
     Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
     */
}

+ (void)enableBackgroundTask
{
    if (backgroundTaskEnabled_) {
        return;
    }
    backgroundTaskEnabled_ = YES;
    
    NSNotificationCenter* notificationCenter = [NSNotificationCenter defaultCenter];
    [notificationCenter addObserver:self
                           selector:@selector(_willResignActive:)
                               name:UIApplicationWillResignActiveNotification
                             object:nil];
    [notificationCenter addObserver:self
                           selector:@selector(_didBecomeActive:)
                               name:UIApplicationDidBecomeActiveNotification
                             object:nil];
}


#pragma mark -
#pragma mark API (called by workers)

- (void)notifyUpdatedWorker:(id <FBWorker>)worker
{
    [self _updateWorker:worker];
}

- (void)notifyFinishedWorker:(id <FBWorker>)worker
{
    [self _setWorker:worker workerState:FBWorkerStateCompleted];
}


#pragma mark -
#pragma mark API (manage workers)

- (BOOL)cancelWorker:(id <FBWorker>)worker
{
    if ([self _setWorker:worker workerState:FBWorkerStateCanceled]) {
        [self _updateWorker:worker];
        return YES;
    }
    return NO;
}

- (BOOL)suspendWorker:(id <FBWorker>)worker
{
    if ([self _setWorker:worker workerState:FBWorkerStateSuspending]) {
        [self _updateWorker:worker];
        return YES;
    }
    return NO;
}

- (BOOL)resumeWorker:(id <FBWorker>)worker
{
    if ([self _setWorker:worker workerState:FBWorkerStateWaiting]) {
        [self _updateWorker:worker];
        return YES;
    }
    return NO;
}

- (void)cancelAllWorkers
{
    for (id <FBWorker> worker in [self.workerSet allObjects]) {
        [self cancelWorker:worker];
    }
}

- (void)suspendAllWorkers
{
    for (id <FBWorker> worker in self.workerSet) {
        [self suspendWorker:worker];
    }    
}

- (void)resumeAllWorkers
{
    for (id <FBWorker> worker in self.workerSet) {
        [self resumeWorker:worker];
    }
}

@end
