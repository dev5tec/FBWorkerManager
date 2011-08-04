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
@synthesize interval = interval_;
@synthesize state = state_;
@synthesize workerQueue = workerQueue_;
@synthesize timer = timer_;
@synthesize workerSet = workerSet_;


#pragma mark -
#pragma mark Privates
- (void)_startThread
{
    // TODO: multi threading
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);

    id <LKWorker> worker;
    
    while ((worker = [self.workerQueue nextWorker])) {
        @synchronized (self.workerSet) {
            [self.workerSet addObject:worker];
        }
        dispatch_async(queue, ^{
            if ([self.delegate respondsToSelector:@selector(willBeginWorkerManager:worker:)]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate willBeginWorkerManager:self worker:worker];
                });
            }
            
            if ([worker executeOnWorkerManager:self]) {           
                if ([self.delegate respondsToSelector:@selector(didFinishWorkerManager:worker:)]) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self.delegate didFinishWorkerManager:self worker:worker];
                    });
                }
                
                @synchronized (self.workerSet) {
                    [self.workerSet removeObject:worker];
                }
            }
        });        
    }

    self.state = LKWorkerManagerStateWaiting;
    
    return;

    // TODO
    dispatch_async(queue, ^{
        
        while (self.state == LKWorkerManagerStateRunning) {
            
            if ([self.workerQueue count] == 0) {
                self.state = LKWorkerManagerStateWaiting;
                break;
            }

            id <LKWorker> worker = [self.workerQueue nextWorker];
            if (worker == nil) {
                self.state = LKWorkerManagerStateWaiting;
                break;
            }

            if ([self.delegate respondsToSelector:@selector(willBeginWorkerManager:worker:)]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate willBeginWorkerManager:self worker:worker];
                });
            }

            if ([worker executeOnWorkerManager:self]) {
                if ([self.delegate respondsToSelector:@selector(didFinishWorkerManager:worker:)]) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self.delegate didFinishWorkerManager:self worker:worker];
                    });
                }
            }
        }
    });
}

- (void)_check:(NSTimer*)timer
{
    if (self.state != LKWorkerManagerStateWaiting) {
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
    
    self.state = LKWorkerManagerStateRunning;
    [self _startThread];
}

- (void)_updateWorker:(id <LKWorker>)worker
{
    if ([self.delegate respondsToSelector:@selector(didUpdateWorkerManager:worker:)]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate didUpdateWorkerManager:self worker:worker];
        });
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

    self.state = LKWorkerManagerStateWaiting;
    [self _check:nil];
    self.timer = [NSTimer scheduledTimerWithTimeInterval:self.interval
                                                  target:self
                                                selector:@selector(_check:)
                                                userInfo:nil
                                                 repeats:YES];
}

// TODO
- (void)stop
{
    self.state = LKWorkerManagerStateStopping;
    if ([self.timer isValid]) {
        [self.timer invalidate];
    }
    self.timer = nil;   
    self.state = LKWorkerManagerStateStopping;
}

- (void)pauseAll
{    
    @synchronized (self.workerSet) {
        for (id <LKWorker> worker in self.workerSet) {
            if ([worker respondsToSelector:@selector(pauseOnWorkerManager:)]) {
                [worker pauseOnWorkerManager:self];
            }
        }
    }
}

- (void)resumeAll
{
    @synchronized (self.workerSet) {
        for (id <LKWorker> worker in self.workerSet) {
            if ([worker respondsToSelector:@selector(resumeOnWorkerManager:)]) {
                [worker resumeOnWorkerManager:self];
            }
        }
    }    
}

- (void)cancelAll
{
    @synchronized (self.workerSet) {
        for (id <LKWorker> worker in self.workerSet) {
            if ([worker respondsToSelector:@selector(cancelOnWorkerManager:)]) {
                [worker cancelOnWorkerManager:self];
            }
        }
        [self.workerSet removeAllObjects];
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

- (void)pauseWorker:(id <LKWorker>)worker
{
    if ([worker respondsToSelector:@selector(pauseOnWorkerManager:)]) {
        [worker pauseOnWorkerManager:self];
    }
    [self _updateWorker:worker];
}

- (void)resumeWorker:(id <LKWorker>)worker
{
    if ([worker respondsToSelector:@selector(resumeOnWorkerManager:)]) {
        [worker resumeOnWorkerManager:self];
    }    
    [self _updateWorker:worker];
}

- (void)cancelWorker:(id <LKWorker>)worker
{
    if ([worker respondsToSelector:@selector(cancelOnWorkerManager:)]) {
        [worker cancelOnWorkerManager:self];
    }        

    if ([self.delegate respondsToSelector:@selector(didCancelWorkerManager:worker:)]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate didCancelWorkerManager:self worker:worker];
        });
    }
}

@end
