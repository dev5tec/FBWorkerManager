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
#define FBWORKERMANAGER_MAX_WORKERS             1

#pragma mark -
@interface FBWorkerManager()
@property (assign) FBWorkerManagerState state;
@property (nonatomic, retain) NSTimer* timer;
@property (nonatomic, retain) NSMutableSet* workerSet;
@end


#pragma mark -
@implementation FBWorkerManager
@synthesize delegate = delegate_;
@synthesize maxWorkers = maxWorkers_;
@synthesize interval = interval_;
@synthesize state = state_;
@synthesize workerSource = workerSource_;
@synthesize timer = timer_;
@synthesize workerSet = workerSet_;

#pragma mark -
#pragma mark Privates

- (BOOL)_checkMaxWorkers
{
    if (self.maxWorkers == 0) {
        return YES;
    }
    
    NSUInteger count = 0;
    @synchronized (self.workerSet) {
        for (id <FBWorker> worker in self.workerSet) {
            if ([worker workerState] == FBWorkerStateExecuting) {
                count++;
            }
        }
    }
    return (count < self.maxWorkers);
}

- (void)_setWorker:(id <FBWorker>)worker workerState:(FBWorkerState)workerSstate
{
    [worker setWorkerState:workerSstate];
    
    switch (workerSstate) {
        case FBWorkerStateWaiting:
            // TODO: resume ?
            if ([worker respondsToSelector:@selector(didResumeWithWorkerManager:)]) {
                [worker didResumeWithWorkerManager:self];
            }
            break;
            
        case FBWorkerStateExecuting:
            break;
            
        case FBWorkerStateSuspending:
            if ([worker respondsToSelector:@selector(didSuspendWithWorkerManager:)]) {
                [worker didSuspendWithWorkerManager:self];
            }
            break;
            
        case FBWorkerStateCompleted:
            if ([self.delegate respondsToSelector:@selector(didFinishWorkerManager:worker:)]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate didFinishWorkerManager:self worker:worker];
                });
            }
            NSLog(@"completed");
            break;
            
        case FBWorkerStateCanceled:
            if ([worker respondsToSelector:@selector(didCancelWithWorkerManager:)]) {
                [worker didCancelWithWorkerManager:self];
            }
            if ([self.delegate respondsToSelector:@selector(didFinishWorkerManager:worker:)]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate didFinishWorkerManager:self worker:worker];
                });
            }
            break;

    }
}

- (void)_updateWorker:(id <FBWorker>)worker
{
    if ([self.delegate respondsToSelector:@selector(didUpdateWorkerManager:worker:)]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate didUpdateWorkerManager:self worker:worker];
        });
    }
}

- (void)_startThread
{
    id <FBWorker> worker;

    while ((worker = [self.workerSource nextWorker])) {
        @synchronized (self.workerSet) {
            [self.workerSet addObject:worker];
        }

        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            if ([self.delegate respondsToSelector:@selector(willBeginWorkerManager:worker:)]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate willBeginWorkerManager:self worker:worker];
                });
            }
            
            if ([worker executeWithWorkerManager:self]) { 
                [self _setWorker:worker workerState:FBWorkerStateCompleted];                
                @synchronized (self.workerSet) {
                    [self.workerSet removeObject:worker];
                }
            }
        });
        
        if (![self _checkMaxWorkers]) {
            break;
        }
    }
}

- (void)_check:(NSTimer*)timer
{
    if (self.state != FBWorkerManagerStateRunning) {
        return;
    }

    if ([self.delegate respondsToSelector:@selector(canWorkerManagerRun)]) {
        if (![self.delegate canWorkerManagerRun]) {
            return;
        }
    }
    
    if ([self _checkMaxWorkers]) {
        [self _startThread];
    }
}


#pragma mark -
#pragma mark Basics

- (id)init
{
    self = [super init];
    if (self) {
        self.interval = FBWORKERMANAGER_TIMEINTERVAL_FOR_CHECK;
        self.state = FBWorkerManagerStateStopping;
        self.maxWorkers = FBWORKERMANAGER_MAX_WORKERS;
        self.workerSet = [NSMutableSet set];
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
#pragma mark API (General)

+ (FBWorkerManager*)workerManager
{
    return [[[self alloc] init] autorelease];
}

- (void)start
{
    if (self.state != FBWorkerManagerStateStopping) {
        return;
    }

    self.state = FBWorkerManagerStateRunning;
    [self _check:nil];
    self.timer = [NSTimer scheduledTimerWithTimeInterval:self.interval
                                                  target:self
                                                selector:@selector(_check:)
                                                userInfo:nil
                                                 repeats:YES];
}

- (void)stop
{
    self.state = FBWorkerManagerStateStopping;
    if ([self.timer isValid]) {
        [self.timer invalidate];
    }
    [self cancelAll];
    self.timer = nil;   
}


static UIBackgroundTaskIdentifier backgroundTaskIdentifer_;
static BOOL backgroundTaskEnabled_ = NO;

+ (void)_willResignActive:(NSNotification*)notification
{
    NSLog(@"%s|%d", __PRETTY_FUNCTION__, backgroundTaskIdentifer_);
    UIApplication* app = [UIApplication sharedApplication];
    
    NSAssert(backgroundTaskIdentifer_ == UIBackgroundTaskInvalid, nil);
    
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
    NSLog(@"%s|%d", __PRETTY_FUNCTION__, backgroundTaskIdentifer_);
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
#pragma mark API (manage workers)


- (void)suspendAll
{
    self.state = FBWorkerManagerStateSuspending;

    @synchronized (self.workerSet) {
        for (id <FBWorker> worker in self.workerSet) {
            [self _setWorker:worker workerState:FBWorkerStateSuspending];
        }
    }
}

- (void)resumeAll
{
    @synchronized (self.workerSet) {
        for (id <FBWorker> worker in self.workerSet) {
            [self _setWorker:worker workerState:FBWorkerStateWaiting];
        }
    }    
    self.state = FBWorkerManagerStateRunning;
}

- (void)cancelAll
{
    @synchronized (self.workerSet) {
        id <FBWorker> worker;
        for (worker in self.workerSet) {
            [self _setWorker:worker workerState:FBWorkerStateCanceled];
        }
        [self.workerSet removeAllObjects];
        
        while ((worker = [self.workerSource nextWorker])) {
            [self _setWorker:worker workerState:FBWorkerStateCanceled];
        }
    }
}


- (void)notifyUpdatedWorker:(id <FBWorker>)worker
{
    [self _updateWorker:worker];
}


#pragma mark -
#pragma mark API (for controller)

- (void)suspendWorker:(id <FBWorker>)worker
{
    [self _setWorker:worker workerState:FBWorkerStateSuspending];
    [self _updateWorker:worker];
}

- (void)resumeWorker:(id <FBWorker>)worker
{
    [self _setWorker:worker workerState:FBWorkerStateWaiting];
    [self _updateWorker:worker];
    if (self.state == FBWorkerManagerStateSuspending) {
        self.state = FBWorkerManagerStateRunning;
    }
}

- (void)cancelWorker:(id <FBWorker>)worker
{
    [self _setWorker:worker workerState:FBWorkerStateCanceled];
    @synchronized (self.workerSet) {
        [self.workerSet removeObject:worker];
    }
}



@end
