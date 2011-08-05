//
//  FBWorkerManager.m
//  FBWorkerManager
//
//  Created by Hashiguchi Hiroshi on 11/08/01.
//  Copyright 2011年 __MyCompanyName__. All rights reserved.
//

#import "FBWorkerManager.h"

#define FBWORKERMANAGER_TIMEINTERVAL_FOR_CHECK  1.0
#define FBWORKERMANAGER_MAX_WORKERS             1

#pragma mark -
@interface FBWorkerManager()
@property (nonatomic, retain) id <FBWorkerQueue> workerQueue;
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
@synthesize workerQueue = workerQueue_;
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

    while ((worker = [self.workerQueue nextWorker])) {
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

    if ([self.workerQueue count] == 0) {
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

- (id)initWithWorkerQueue:(id <FBWorkerQueue>)workerQueue
{
    self = [super init];
    if (self) {
        self.interval = FBWORKERMANAGER_TIMEINTERVAL_FOR_CHECK;
        self.state = FBWorkerManagerStateStopping;
        self.maxWorkers = FBWORKERMANAGER_MAX_WORKERS;
        self.workerQueue = workerQueue;
        self.workerSet = [NSMutableSet set];
    }
    
    return self;
}

- (void)dealloc {
    if ([self.timer isValid]) {
        [self.timer invalidate];
    }
    self.timer = nil;
    self.workerQueue = nil;
    [super dealloc];
}

#pragma mark -
#pragma mark API (General)

+ (FBWorkerManager*)workerManagerWithWorkerQueue:(id <FBWorkerQueue>)workerQueue
{
    return [[[self alloc] initWithWorkerQueue:workerQueue] autorelease];
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
        
        while ((worker = [self.workerQueue nextWorker])) {
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
