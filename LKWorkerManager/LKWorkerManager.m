//
//  LKWorkerManager.m
//  LKWorkerManager
//
//  Created by Hashiguchi Hiroshi on 11/08/01.
//  Copyright 2011年 __MyCompanyName__. All rights reserved.
//

#import "LKWorkerManager.h"
#import "LKWorker.h"

#define LKWORKERMANAGER_TIMEINTERVAL_FOR_CHECK  1.0
#define LKWORKERMANAGER_MAX_WORKERS             1

#pragma mark -
@interface LKWorkerManager()
@property (nonatomic, retain) id <LKWorkerQueue> workerQueue;
@property (assign) LKWorkerManagerState state;
@property (nonatomic, retain) NSTimer* timer;
@property (nonatomic, retain) NSMutableSet* workerSet;
@end


#pragma mark -
@implementation LKWorkerManager
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
        for (id <LKWorker> worker in self.workerSet) {
            if ([worker workerState] == LKWorkerStateExecuting) {
                count++;
            }
        }
    }
    return (count < self.maxWorkers);
}

- (void)_setWorker:(id <LKWorker>)worker workerState:(LKWorkerState)workerSstate
{
    [worker setWorkerState:workerSstate];
    
    switch (workerSstate) {
        case LKWorkerStateWaiting:
            // TODO: resume ?
            if ([worker respondsToSelector:@selector(didResumeWithWorkerManager:)]) {
                [worker didResumeWithWorkerManager:self];
            }
            break;
            
        case LKWorkerStateExecuting:
            break;
            
        case LKWorkerStateSuspending:
            if ([worker respondsToSelector:@selector(didSuspendWithWorkerManager:)]) {
                [worker didSuspendWithWorkerManager:self];
            }
            break;
            
        case LKWorkerStateCompleted:
            if ([self.delegate respondsToSelector:@selector(didFinishWorkerManager:worker:)]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate didFinishWorkerManager:self worker:worker];
                });
            }
            NSLog(@"completed");
            break;
            
        case LKWorkerStateCanceled:
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

- (void)_updateWorker:(id <LKWorker>)worker
{
    if ([self.delegate respondsToSelector:@selector(didUpdateWorkerManager:worker:)]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate didUpdateWorkerManager:self worker:worker];
        });
    }
}

- (void)_startThread
{
    id <LKWorker> worker;

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
                [self _setWorker:worker workerState:LKWorkerStateCompleted];                
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
    if (self.state != LKWorkerManagerStateRunning) {
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

- (id)initWithWorkerQueue:(id <LKWorkerQueue>)workerQueue
{
    self = [super init];
    if (self) {
        self.interval = LKWORKERMANAGER_TIMEINTERVAL_FOR_CHECK;
        self.state = LKWorkerManagerStateStopping;
        self.maxWorkers = LKWORKERMANAGER_MAX_WORKERS;
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

+ (LKWorkerManager*)workerManagerWithWorkerQueue:(id <LKWorkerQueue>)workerQueue
{
    return [[[self alloc] initWithWorkerQueue:workerQueue] autorelease];
}

- (void)start
{
    if (self.state != LKWorkerManagerStateStopping) {
        return;
    }

    self.state = LKWorkerManagerStateRunning;
    [self _check:nil];
    self.timer = [NSTimer scheduledTimerWithTimeInterval:self.interval
                                                  target:self
                                                selector:@selector(_check:)
                                                userInfo:nil
                                                 repeats:YES];
}

- (void)stop
{
    self.state = LKWorkerManagerStateStopping;
    if ([self.timer isValid]) {
        [self.timer invalidate];
    }
    [self cancelAll];
    self.timer = nil;   
}

- (void)suspendAll
{
    self.state = LKWorkerManagerStateSuspending;

    @synchronized (self.workerSet) {
        for (id <LKWorker> worker in self.workerSet) {
            [self _setWorker:worker workerState:LKWorkerStateSuspending];
        }
    }
}

- (void)resumeAll
{
    @synchronized (self.workerSet) {
        for (id <LKWorker> worker in self.workerSet) {
            [self _setWorker:worker workerState:LKWorkerStateWaiting];
        }
    }    
    self.state = LKWorkerManagerStateRunning;
}

- (void)cancelAll
{
    @synchronized (self.workerSet) {
        id <LKWorker> worker;
        for (worker in self.workerSet) {
            [self _setWorker:worker workerState:LKWorkerStateCanceled];
        }
        [self.workerSet removeAllObjects];
        
        while ((worker = [self.workerQueue nextWorker])) {
            [self _setWorker:worker workerState:LKWorkerStateCanceled];
        }
    }
}


#pragma mark -
#pragma mark API (for worker)

- (void)notifyUpdatedWorker:(id <LKWorker>)worker
{
    [self _updateWorker:worker];
}


#pragma mark -
#pragma mark API (for controller)

- (void)suspendWorker:(id <LKWorker>)worker
{
    [self _setWorker:worker workerState:LKWorkerStateSuspending];
    [self _updateWorker:worker];
}

- (void)resumeWorker:(id <LKWorker>)worker
{
    [self _setWorker:worker workerState:LKWorkerStateWaiting];
    [self _updateWorker:worker];
    if (self.state == LKWorkerManagerStateSuspending) {
        self.state = LKWorkerManagerStateRunning;
    }
}

- (void)cancelWorker:(id <LKWorker>)worker
{
    [self _setWorker:worker workerState:LKWorkerStateCanceled];
    @synchronized (self.workerSet) {
        [self.workerSet removeObject:worker];
    }
}


#pragma mark -
#pragma mark API (background)
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

@end
