//
//  SJVideoPlayerDefaultControlView.m
//  SJVideoPlayerProject
//
//  Created by BlueDancer on 2018/2/6.
//  Copyright © 2018年 SanJiang. All rights reserved.
//

#import "SJVideoPlayerDefaultControlView.h"
#import "SJVideoPlayerBottomControlView.h"
#import <Masonry/Masonry.h>
#import "SJVideoPlayer.h"
#import "SJVideoPlayerSettings.h"
#import "SJVideoPlayerDraggingProgressView.h"
#import "UIView+SJVideoPlayerSetting.h"
#import <SJSlider/SJSlider.h>
#import "SJVideoPlayerLeftControlView.h"
#import "SJVideoPlayerTopControlView.h"
#import "SJVideoPlayerPreviewView.h"
#import "SJVideoPlayerMoreSettingsView.h"
#import "SJVideoPlayerMoreSettingSecondaryView.h"
#import "SJMoreSettingsSlidersViewModel.h"
#import "SJVideoPlayerMoreSetting+Exe.h"
#import "SJVideoPlayerMoreSettingSecondary.h"
#import "SJVideoPlayerCenterControlView.h"
#import <SJLoadingView/SJLoadingView.h>
#import <objc/message.h>
#import "UIView+SJControlAdd.h"
#import "SJVideoPlayerRightControlView.h"
#import "SJVideoPlayerFilmEditingControlView.h"
#import "SJVideoPlayerControlMaskView.h"
#import <SJUIFactory/SJUIFactory.h>
#import "SJVideoPlayerAnimationHeader.h"
#import <SJBaseVideoPlayer/SJTimerControl.h>
#import <SJBaseVideoPlayer/SJVideoPlayerRegistrar.h>
#import "SJVideoPlayerPropertyRecorder.h"

#pragma mark -

NS_ASSUME_NONNULL_BEGIN

#pragma mark -
@interface SJVideoPlayerDefaultControlView ()<SJVideoPlayerLeftControlViewDelegate, SJVideoPlayerBottomControlViewDelegate, SJVideoPlayerTopControlViewDelegate, SJVideoPlayerPreviewViewDelegate, SJVideoPlayerCenterControlViewDelegate, SJVideoPlayerRightControlViewDelegate, SJVideoPlayerFilmEditingControlViewDataSource, SJVideoPlayerFilmEditingControlViewDelegate> {
    SJTimerControl *_lockStateTappedTimerControl;
}

@property (nonatomic, weak, readwrite, nullable) SJVideoPlayer *videoPlayer;    // need weak ref.

@property (nonatomic, assign) BOOL hasBeenGeneratedPreviewImages;
@property (nonatomic, strong, readonly) SJMoreSettingsSlidersViewModel *footerViewModel;

@property (nonatomic, strong, readonly) UIView *containerView;
@property (nonatomic, strong, readonly) SJVideoPlayerPreviewView *previewView;
@property (nonatomic, strong, readonly) SJVideoPlayerDraggingProgressView *draggingProgressView;
@property (nonatomic, strong, readonly) SJVideoPlayerTopControlView *topControlView;
@property (nonatomic, strong, readonly) SJVideoPlayerControlMaskView *topControlMaskView;
@property (nonatomic, strong, readonly) SJVideoPlayerLeftControlView *leftControlView;
@property (nonatomic, strong, readonly) SJVideoPlayerCenterControlView *centerControlView;
@property (nonatomic, strong, readonly) SJVideoPlayerBottomControlView *bottomControlView;
@property (nonatomic, strong, readonly) SJVideoPlayerControlMaskView *bottomControlMaskView;
@property (nonatomic, strong, readonly) SJVideoPlayerRightControlView *rightControlView;
@property (nonatomic, strong, readonly) SJSlider *bottomSlider;
@property (nonatomic, strong, readonly) SJVideoPlayerMoreSettingsView *moreSettingsView;
@property (nonatomic, strong, readonly) SJVideoPlayerMoreSettingSecondaryView *moreSecondarySettingView;
@property (nonatomic, strong, readonly) SJLoadingView *loadingView;
@property (nonatomic, strong, readonly) SJTimerControl *lockStateTappedTimerControl;
@property (nonatomic, strong, readonly) SJVideoPlayerRegistrar *registrar;
@property (nonatomic, strong, readwrite, nullable) SJVideoPlayerFilmEditingControlView *filmEditingControlView;
@property (nonatomic, strong, readwrite, nullable) SJVideoPlayerSettings *settings;

@property (nonatomic, strong, nullable) SJVideoPlayerPropertyRecorder *propertyRecorder;

@end
NS_ASSUME_NONNULL_END

@implementation SJVideoPlayerDefaultControlView

@synthesize previewView = _previewView;
@synthesize containerView = _containerView;
@synthesize draggingProgressView = _draggingProgressView;
@synthesize topControlView = _topControlView;
@synthesize leftControlView = _leftControlView;
@synthesize centerControlView = _centerControlView;
@synthesize bottomControlView = _bottomControlView;
@synthesize rightControlView = _rightControlView;
@synthesize bottomSlider = _bottomSlider;
@synthesize moreSettingsView = _moreSettingsView;
@synthesize moreSecondarySettingView = _moreSecondarySettingView;
@synthesize footerViewModel = _footerViewModel;
@synthesize loadingView = _loadingView;
@synthesize filmEditingControlView = _filmEditingControlView;
@synthesize topControlMaskView = _topControlMaskView;
@synthesize bottomControlMaskView = _bottomControlMaskView;
@synthesize registrar = _registrar;

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if ( !self ) return nil;
    [self _controlViewSetupView];
    [self _controlViewLoadSetting];
    // default values
    _generatePreviewImages = YES;
    return self;
}

- (void)dealloc {
#ifdef DEBUG
    NSLog(@"SJVideoPlayerLog: %d - %s", (int)__LINE__, __func__);
#endif
}

#pragma mark - Player extension

- (void)Extension_pauseAndDeterAppear {
    BOOL old = self.videoPlayer.pausedToKeepAppearState;
    self.videoPlayer.pausedToKeepAppearState = NO;              // Deter Appear
    [self.videoPlayer pause];
    self.videoPlayer.pausedToKeepAppearState = old;             // resume
}

#pragma mark - Player dataSrouce

/// 播放器安装完控制层的回调.
- (void)installedControlViewToVideoPlayer:(SJVideoPlayer *)videoPlayer {
    self.videoPlayer = videoPlayer;
}

- (UIView *)controlView {
    return self;
}

/// 控制层需要隐藏之前会调用这个方法, 如果返回NO, 将不调用`controlLayerNeedDisappear:`.
- (BOOL)controlLayerDisappearCondition {
    if ( self.previewView.appearState ) return NO;          // 如果预览视图显示, 则不隐藏控制层
    if ( SJVideoPlayerPlayState_PlayFailed == self.videoPlayer.state ) return NO;
    return YES;
}

/// 触发手势之前会调用这个方法, 如果返回NO, 将不调用水平手势相关的代理方法.
- (BOOL)triggerGesturesCondition:(CGPoint)location {
    if ( CGRectContainsPoint(self.moreSettingsView.frame, location) ||
        CGRectContainsPoint(self.moreSecondarySettingView.frame, location) ||
        CGRectContainsPoint(self.previewView.frame, location) ) return NO;
    return YES;
}

#pragma mark - Player prepareToPlay

/// 当设置播放资源时调用.
- (void)videoPlayer:(SJVideoPlayer *)videoPlayer prepareToPlay:(SJVideoPlayerURLAsset *)asset {
    // reset
    self.topControlView.model.alwaysShowTitle = asset.alwaysShowTitle;
    self.topControlView.model.title = asset.title;
    self.topControlView.model.isPlayOnScrollView = videoPlayer.isPlayOnScrollView;
    self.topControlView.model.fullscreen = videoPlayer.isFullScreen;
    [self.topControlView update];
    
    
    self.bottomSlider.value = 0;
    self.bottomControlView.progress = 0;
    self.bottomControlView.bufferProgress = 0;
    [self.bottomControlView setCurrentTimeStr:@"00:00" totalTimeStr:@"00:00"];
    
    [self _promptWithNetworkStatus:videoPlayer.networkStatus];
    self.propertyRecorder = [[SJVideoPlayerPropertyRecorder alloc] initWithVideoPlayer:videoPlayer];
    self.enableFilmEditing = videoPlayer.enableFilmEditing;
    _rightControlView.hidden = asset.isM3u8;
}

#pragma mark - Control layer appear / disappear
/// 显示边缘控制视图
- (void)controlLayerNeedAppear:(SJVideoPlayer *)videoPlayer {
    UIView_Animations(CommonAnimaDuration, ^{
        if ( SJVideoPlayerPlayState_PlayFailed == videoPlayer.state ) {
            [self->_centerControlView failedState];
            [self->_centerControlView appear];
            [self->_topControlView appear];
            [self->_leftControlView disappear];
            [self->_bottomControlView disappear];
            [self->_rightControlView disappear];
        }
        else {
            // top
            if ( videoPlayer.isPlayOnScrollView && !videoPlayer.isFullScreen ) {
                if ( videoPlayer.URLAsset.alwaysShowTitle ) [self->_topControlView appear];
                else [self->_topControlView disappear];
            }
            else [self->_topControlView appear];
            
            [self->_bottomControlView appear];
            
            if ( videoPlayer.isFullScreen ) {
                [self->_leftControlView appear];
                [self->_rightControlView appear];
            }
            else {
                [self->_leftControlView disappear];  // 如果是小屏, 则不显示锁屏按钮
                [self->_rightControlView disappear];
            }
            [self->_bottomSlider disappear];
            
            if ( videoPlayer.state != SJVideoPlayerPlayState_PlayEnd ) [self->_centerControlView disappear];
        }
        
        if ( self->_moreSettingsView.appearState ) [self->_moreSettingsView disappear];
        if ( self->_moreSecondarySettingView.appearState ) [self->_moreSecondarySettingView disappear];
    }, nil);
}

/// 隐藏边缘控制视图
- (void)controlLayerNeedDisappear:(SJVideoPlayer *)videoPlayer {
    UIView_Animations(CommonAnimaDuration, ^{
        if ( SJVideoPlayerPlayState_PlayFailed != videoPlayer.state ) {
            [self->_topControlView disappear];
            [self->_bottomControlView disappear];
            [self->_rightControlView disappear];
            if ( !videoPlayer.isLockedScreen ) [self->_leftControlView disappear];
            else [self->_leftControlView appear];
            [self->_previewView disappear];
            [self->_bottomSlider appear];
        }
        else {
            [self->_topControlView appear];
            [self->_leftControlView disappear];
            [self->_bottomControlView disappear];
            [self->_rightControlView disappear];
        }
    }, nil);
}

///  在`tableView`或`collectionView`上将要显示的时候调用.
- (void)videoPlayerWillAppearInScrollView:(SJVideoPlayer *)videoPlayer {
    videoPlayer.view.hidden = NO;
}

///  在`tableView`或`collectionView`上将要消失的时候调用.
- (void)videoPlayerWillDisappearInScrollView:(SJVideoPlayer *)videoPlayer {
    [videoPlayer pause];
    videoPlayer.view.hidden = YES;
}

/// 播放状态改变.
- (void)videoPlayer:(SJVideoPlayer *)videoPlayer stateChanged:(SJVideoPlayerPlayState)state {
    switch ( state ) {
        case SJVideoPlayerPlayState_Unknown: {
            [videoPlayer controlLayerNeedDisappear];
            self.topControlView.model.title = nil;
            [self.topControlView update];
            self.bottomSlider.value = 0;
            self.bottomControlView.progress = 0;
            self.bottomControlView.bufferProgress = 0;
            [self.bottomControlView setCurrentTimeStr:@"00:00" totalTimeStr:@"00:00"];
        }
            break;
        case SJVideoPlayerPlayState_Prepare: {
            
        }
            break;
        case SJVideoPlayerPlayState_Paused:
        case SJVideoPlayerPlayState_PlayFailed:
        case SJVideoPlayerPlayState_PlayEnd: {
            self.bottomControlView.playState = NO;
        }
            break;
        case SJVideoPlayerPlayState_Playing: {
            self.bottomControlView.playState = YES;
        }
            break;
        case SJVideoPlayerPlayState_Buffing: {
            if ( self.centerControlView.appearState ) {
                UIView_Animations(CommonAnimaDuration, ^{
                    [self.centerControlView disappear];
                }, nil);
            }
        }
            break;
    }
    
    if ( SJVideoPlayerPlayState_PlayFailed == state ) {
#ifdef DEBUG
        NSLog(@"SJVideoPlayerLog: %@", videoPlayer.error);
#endif
        [self.loadingView stop];
    }
    
    if ( SJVideoPlayerPlayState_PlayEnd ==  state ) {
        UIView_Animations(CommonAnimaDuration, ^{
            [self.centerControlView appear];
            [self.centerControlView replayState];
        }, nil);
        
        if ( _filmEditingControlView && _filmEditingControlView.status == SJVideoPlayerFilmEditingStatus_Recording ) {
            [videoPlayer showTitle:self.settings.videoPlayDidToEndText duration:2];
            [_filmEditingControlView finalize];
        }
    }
}

#pragma mark Play progress
/// 播放进度回调.
- (void)videoPlayer:(SJVideoPlayer *)videoPlayer
        currentTime:(NSTimeInterval)currentTime currentTimeStr:(NSString *)currentTimeStr
          totalTime:(NSTimeInterval)totalTime totalTimeStr:(NSString *)totalTimeStr {
    [self.bottomControlView setCurrentTimeStr:currentTimeStr totalTimeStr:totalTimeStr];
    float progress = videoPlayer.progress;
    self.bottomControlView.progress = progress;
    self.bottomSlider.value = progress;
    if ( self.draggingProgressView.appearState ) self.draggingProgressView.playProgress = progress;
}

/// 缓冲的进度.
- (void)videoPlayer:(SJVideoPlayer *)videoPlayer loadedTimeProgress:(float)progress {
    self.bottomControlView.bufferProgress = progress;
}

/// 开始缓冲.
- (void)startLoading:(SJVideoPlayer *)videoPlayer {
    [self.loadingView start];
}

- (void)cancelLoading:(__kindof SJBaseVideoPlayer *)videoPlayer {
    [self.loadingView stop];
}

/// 缓冲完成.
- (void)loadCompletion:(SJVideoPlayer *)videoPlayer {
    [self.loadingView stop];
}
#pragma mark Player lock / unlock / tapped
/// 播放器被锁屏, 此时将不旋转, 不触发手势相关事件.
- (void)lockedVideoPlayer:(SJVideoPlayer *)videoPlayer {
    _leftControlView.lockState = YES;
    [self.lockStateTappedTimerControl start];
    [videoPlayer controlLayerNeedDisappear];
}

/// 播放器解除锁屏.
- (void)unlockedVideoPlayer:(SJVideoPlayer *)videoPlayer {
    _leftControlView.lockState = NO;
    [self.lockStateTappedTimerControl clear];
    [videoPlayer controlLayerNeedAppear];
}

/// 如果播放器锁屏, 当用户点击的时候, 这个方法会触发
- (void)tappedPlayerOnTheLockedState:(__kindof SJBaseVideoPlayer *)videoPlayer {
    UIView_Animations(CommonAnimaDuration, ^{
        if ( self->_leftControlView.appearState ) [self->_leftControlView disappear];
        else [self->_leftControlView appear];
    }, nil);
    if ( _leftControlView.appearState ) [_lockStateTappedTimerControl start];
    else [_lockStateTappedTimerControl clear];
}

#pragma mark Player Rotation
/// 播放器将要旋转屏幕, `isFull`如果为`YES`, 则全屏.
- (void)videoPlayer:(SJVideoPlayer *)videoPlayer willRotateView:(BOOL)isFull {
    if ( isFull && !videoPlayer.URLAsset.isM3u8 ) {
        self.draggingProgressView.style = SJVideoPlayerDraggingProgressViewStylePreviewProgress;
    }
    else {
        self.draggingProgressView.style = SJVideoPlayerDraggingProgressViewStyleArrowProgress;
    }
    
    // update layout
    self.bottomControlView.fullscreen = isFull;
    self.topControlView.model.fullscreen = isFull;
    [self.topControlView update];
    SJAutoRotateSupportedOrientation supportedOrientation = _videoPlayer.supportedOrientation;
    if ( supportedOrientation == SJAutoRotateSupportedOrientation_All ) {
        supportedOrientation = SJAutoRotateSupportedOrientation_Portrait | SJAutoRotateSupportedOrientation_LandscapeLeft | SJAutoRotateSupportedOrientation_LandscapeRight;
    }
    _bottomControlView.onlyLandscape = SJAutoRotateSupportedOrientation_Portrait != (SJAutoRotateSupportedOrientation_Portrait & supportedOrientation);
    
    [self _setControlViewsDisappearValue]; // update. `reset`.
    
    if ( _previewView.appearState ) [_previewView disappear];
    if ( _moreSettingsView.appearState ) [_moreSettingsView disappear];
    if ( _moreSecondarySettingView.appearState ) [_moreSecondarySettingView disappear];
    [self.bottomSlider disappear];
    
    if ( isFull ) {
        // `iPhone_X` remake constraints.
        if ( SJ_is_iPhoneX() ) {
            [self.containerView mas_remakeConstraints:^(MASConstraintMaker *make) {
                make.center.offset(0);
                make.height.equalTo(self.containerView.superview);
                make.width.equalTo(self.containerView.mas_height).multipliedBy(16 / 9.0f);
            }];
        }
    }
    else {
        // `iPhone_X` remake constraints.
        if ( SJ_is_iPhoneX() ) {
            [self.containerView mas_remakeConstraints:^(MASConstraintMaker *make) {
                make.edges.offset(0);
            }];
        }
    }
    
    if ( videoPlayer.controlLayerAppeared ) [videoPlayer controlLayerNeedAppear]; // update
}

/// 播放器完成旋转.
//- (void)videoPlayer:(SJVideoPlayer *)videoPlayer didEndRotation:(BOOL)isFull {
//    
//}

#pragma mark Player Volume / Brightness / Rate
/// 声音被改变.
- (void)videoPlayer:(SJVideoPlayer *)videoPlayer volumeChanged:(float)volume {
    if ( _footerViewModel.volumeChanged ) _footerViewModel.volumeChanged(volume);
}

/// 亮度被改变.
- (void)videoPlayer:(SJVideoPlayer *)videoPlayer brightnessChanged:(float)brightness {
    if ( _footerViewModel.brightnessChanged ) _footerViewModel.brightnessChanged(brightness);
}

/// 播放速度被改变.
- (void)videoPlayer:(SJVideoPlayer *)videoPlayer rateChanged:(float)rate {
    [videoPlayer showTitle:[NSString stringWithFormat:@"%.0f %%", rate * 100]];
    if ( _footerViewModel.playerRateChanged ) _footerViewModel.playerRateChanged(rate);
}

#pragma mark Player Horizontal Gesture
/// 水平方向开始拖动.
- (void)horizontalDirectionWillBeginDragging:(SJVideoPlayer *)videoPlayer {
    [self sliderWillBeginDraggingForBottomView:self.bottomControlView];
}

- (void)videoPlayer:(__kindof SJBaseVideoPlayer *)videoPlayer horizontalDirectionDidMove:(CGFloat)progress {
    [self bottomView:self.bottomControlView sliderDidDrag:progress];
}

/// 水平方向拖动结束.
- (void)horizontalDirectionDidEndDragging:(SJVideoPlayer *)videoPlayer {
    [self sliderDidEndDraggingForBottomView:self.bottomControlView];
}

#pragma mark Player Size
- (void)videoPlayer:(SJVideoPlayer *)videoPlayer presentationSize:(CGSize)size {
    if ( !self.generatePreviewImages ) return;
    CGFloat scale = size.width / size.height;
    CGSize previewItemSize = CGSizeMake(scale * self.previewView.intrinsicContentSize.height * 2, self.previewView.intrinsicContentSize.height * 2);
    __weak typeof(self) _self = self;
    [videoPlayer generatedPreviewImagesWithMaxItemSize:previewItemSize completion:^(SJVideoPlayer * _Nonnull player, NSArray<id<SJVideoPlayerPreviewInfo>> * _Nullable images, NSError * _Nullable error) {
        __strong typeof(_self) self = _self;
        if ( !self ) return ;
        if ( error ) {
#ifdef DEBUG
            NSLog(@"SJVideoPlayerLog: Generate Preview Image Failed! error: %@", error);
#endif
        }
        else {
            self.hasBeenGeneratedPreviewImages = YES;
            self.previewView.previewImages = images;
            self.topControlView.model.fullscreen = player.isFullScreen;
            [self.topControlView update];
        }
    }];
}

#pragma mark - Player Network
- (void)videoPlayer:(SJBaseVideoPlayer *)videoPlayer reachabilityChanged:(SJNetworkStatus)status {
    [self _promptWithNetworkStatus:status];
}

- (void)_promptWithNetworkStatus:(SJNetworkStatus)status {
    if ( self.videoPlayer.disableNetworkStatusChangePrompt ) return;
    if ( [self.videoPlayer.assetURL isFileURL] ) return; // return when is local video.
    if ( !self.settings ) return;
 
    switch ( status ) {
        case SJNetworkStatus_NotReachable: {
            [self.videoPlayer showTitle:self.settings.notReachablePrompt duration:3];
        }
            break;
        case SJNetworkStatus_ReachableViaWWAN: {
            [self.videoPlayer showTitle:self.settings.reachableViaWWANPrompt duration:3];
        }
            break;
        case SJNetworkStatus_ReachableViaWiFi: {
            
        }
            break;
    }
}






#pragma mark - setup views
- (void)_controlViewSetupView {
    
    [self addSubview:self.topControlMaskView];
    [self addSubview:self.bottomControlMaskView];
    [self addSubview:self.containerView];
    
    [self.containerView addSubview:self.topControlView];
    [self.containerView addSubview:self.leftControlView];
    [self.containerView addSubview:self.centerControlView];
    [self.containerView addSubview:self.bottomControlView];
    [self.containerView addSubview:self.draggingProgressView];
    [self.containerView addSubview:self.bottomSlider];
    [self.containerView addSubview:self.previewView];
    [self.containerView addSubview:self.loadingView];
    
    [_topControlMaskView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.leading.trailing.offset(0);
        make.height.equalTo(self->_topControlView);
    }];
    
    [_topControlView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.leading.trailing.offset(0);
    }];
    
    [_containerView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.offset(0);
    }];
    
    [_leftControlView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.leading.offset(0);
        make.centerY.offset(0);
    }];
    
    [_centerControlView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.center.offset(0);
    }];
    
    [_bottomControlMaskView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.leading.bottom.trailing.offset(0);
        make.height.equalTo(self->_bottomControlView);
    }];
    
    [_bottomControlView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.leading.bottom.trailing.offset(0);
    }];
    
    [_draggingProgressView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.center.offset(0);
    }];
    
    [_bottomSlider mas_makeConstraints:^(MASConstraintMaker *make) {
        make.leading.bottom.trailing.offset(0);
        make.height.offset(1);
    }];
    
    [_previewView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self->_topControlView.mas_bottom);
        make.leading.trailing.offset(0);
    }];
    
    [_moreSettingsView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.trailing.offset(0);
        make.size.mas_offset(self->_moreSettingsView.intrinsicContentSize);
    }];
    
    [_loadingView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.center.offset(0);
    }];

    [self _setControlViewsDisappearValue];
    
    [_bottomSlider disappear];
    [_draggingProgressView disappear];
    [_topControlView disappear];
    [_leftControlView disappear];
    [_centerControlView disappear];
    [_bottomControlView disappear];
    [_previewView disappear];
    [_moreSettingsView disappear];
    [_moreSecondarySettingView disappear];
}

- (void)_setControlViewsDisappearValue {
    
    __weak typeof(self) _self = self;
    _topControlView.appearExeBlock = ^(__kindof UIView * _Nonnull view) {
        __strong typeof(_self) self = _self;
        if ( !self ) return;
        [self.topControlMaskView appear];
    };
    
    _topControlView.disappearExeBlock = ^(__kindof UIView * _Nonnull view) {
        __strong typeof(_self) self = _self;
        if ( !self ) return;
        [self.topControlMaskView disappear];
    };
    
    _bottomControlView.appearExeBlock = ^(__kindof UIView * _Nonnull view) {
        __strong typeof(_self) self = _self;
        if ( !self ) return;
        [self.bottomControlMaskView appear];
    };
    
    _bottomControlView.disappearExeBlock = ^(__kindof UIView * _Nonnull view) {
        __strong typeof(_self) self = _self;
        if ( !self ) return;
        [self.bottomControlMaskView disappear];
    };
    
    _topControlMaskView.disappearType = _topControlView.disappearType = SJDisappearType_Transform;
    _topControlMaskView.disappearTransform = _topControlView.disappearTransform = CGAffineTransformMakeTranslation(0, -_topControlView.intrinsicContentSize.height);

    _leftControlView.disappearType = SJDisappearType_Transform;
    _leftControlView.disappearTransform = CGAffineTransformMakeTranslation(-_leftControlView.intrinsicContentSize.width, 0);

    _centerControlView.disappearType = SJDisappearType_Alpha;

    _bottomControlMaskView.disappearType = _bottomControlView.disappearType = SJDisappearType_Transform;
    _bottomControlMaskView.disappearTransform = _bottomControlView.disappearTransform = CGAffineTransformMakeTranslation(0, _bottomControlView.intrinsicContentSize.height);

    _rightControlView.disappearType = SJDisappearType_Transform;
    _rightControlView.disappearTransform = CGAffineTransformMakeTranslation(_rightControlView.intrinsicContentSize.width, 0);
    
    _bottomSlider.disappearType = SJDisappearType_Alpha;
    
    _previewView.disappearType = SJDisappearType_All;
    _previewView.disappearTransform = CGAffineTransformMakeScale(1, 0.001);

    self.moreSettingsView.disappearType = SJDisappearType_Transform;
    _moreSettingsView.disappearTransform = CGAffineTransformMakeTranslation(_moreSettingsView.intrinsicContentSize.width, 0);

    self.moreSecondarySettingView.disappearType = SJDisappearType_Transform;
    _moreSecondarySettingView.disappearTransform = CGAffineTransformMakeTranslation(_moreSecondarySettingView.intrinsicContentSize.width, 0);

    _draggingProgressView.disappearType = SJDisappearType_Alpha;
}

- (UIView *)containerView {
    if ( _containerView ) return _containerView;
    _containerView = [UIView new];
    _containerView.clipsToBounds = YES;
    return _containerView;
}

#pragma mark - Preview view
- (SJVideoPlayerPreviewView *)previewView {
    if ( _previewView ) return _previewView;
    _previewView = [SJVideoPlayerPreviewView new];
    _previewView.delegate = self;
    _previewView.backgroundColor = [UIColor colorWithWhite:0 alpha:0.4];
    return _previewView;
}

- (void)previewView:(SJVideoPlayerPreviewView *)view didSelectItem:(id<SJVideoPlayerPreviewInfo>)item {
    __weak typeof(self) _self = self;
    [_videoPlayer seekToTime:item.localTime completionHandler:^(BOOL finished) {
        __strong typeof(_self) self = _self;
        if ( !self ) return ;
        [self.videoPlayer play];
    }];
}

#pragma mark - Top control view
- (SJVideoPlayerTopControlView *)topControlView {
    if ( _topControlView ) return _topControlView;
    _topControlView = [SJVideoPlayerTopControlView new];
    _topControlView.delegate = self;
    return _topControlView;
}

- (SJVideoPlayerControlMaskView *)topControlMaskView {
    if ( _topControlMaskView ) return _topControlMaskView;
    _topControlMaskView = [[SJVideoPlayerControlMaskView alloc] initWithStyle:SJMaskStyle_top];
    return _topControlMaskView;
}

- (BOOL)hasBeenGeneratedPreviewImages {
    return _hasBeenGeneratedPreviewImages;
}

- (void)topControlView:(SJVideoPlayerTopControlView *)view clickedBtnTag:(SJVideoPlayerTopViewTag)tag {
    switch ( tag ) {
        case SJVideoPlayerTopViewTag_Back: {
            if ( _videoPlayer.isFullScreen ) {
                SJAutoRotateSupportedOrientation supported = _videoPlayer.supportedOrientation;
                if ( supported == SJAutoRotateSupportedOrientation_All ) {
                    supported  = SJAutoRotateSupportedOrientation_Portrait | SJAutoRotateSupportedOrientation_LandscapeLeft | SJAutoRotateSupportedOrientation_LandscapeRight;
                }
                if ( SJAutoRotateSupportedOrientation_Portrait == (supported & SJAutoRotateSupportedOrientation_Portrait) ) {
                    [_videoPlayer rotate];
                    return;
                }
            }
            if ( _videoPlayer.clickedBackEvent ) _videoPlayer.clickedBackEvent(_videoPlayer);
        }
            break;
        case SJVideoPlayerTopViewTag_More: {
            if ( !_moreSettingsView.superview ) {
                [self addSubview:_moreSettingsView];
                [_moreSettingsView mas_makeConstraints:^(MASConstraintMaker *make) {
                    make.top.trailing.offset(0);
                    make.size.mas_offset(self->_moreSettingsView.intrinsicContentSize);
                }];
            }
            [_videoPlayer controlLayerNeedDisappear];
            UIView_Animations(CommonAnimaDuration, ^{
                [self->_moreSettingsView appear];
            }, nil);
        }
            break;
        case SJVideoPlayerTopViewTag_Preview: {
            if ( self.previewView.appearState )  [self.videoPlayer controlLayerNeedAppear];
            UIView_Animations(CommonAnimaDuration, ^{
                if ( !self.previewView.appearState ) [self.previewView appear];
                else [self.previewView disappear];
            }, nil);
        }
            break;
    }
}

#pragma mark - Left control view
- (SJVideoPlayerLeftControlView *)leftControlView {
    if ( _leftControlView ) return _leftControlView;
    _leftControlView = [SJVideoPlayerLeftControlView new];
    _leftControlView.delegate = self;
    return _leftControlView;
}

- (void)leftControlView:(SJVideoPlayerLeftControlView *)view clickedBtnTag:(SJVideoPlayerLeftViewTag)tag {
    switch ( tag ) {
        case SJVideoPlayerLeftViewTag_Lock: {
            _videoPlayer.lockedScreen = NO;  // 点击锁定按钮, 解锁
        }
            break;
        case SJVideoPlayerLeftViewTag_Unlock: {
            _videoPlayer.lockedScreen = YES; // 点击解锁按钮, 锁定
        }
            break;
    }
}


#pragma mark - Center control view
- (SJVideoPlayerCenterControlView *)centerControlView {
    if ( _centerControlView ) return _centerControlView;
    _centerControlView = [SJVideoPlayerCenterControlView new];
    _centerControlView.delegate = self;
    return _centerControlView;
}

- (void)centerControlView:(SJVideoPlayerCenterControlView *)view clickedBtnTag:(SJVideoPlayerCenterViewTag)tag {
    switch ( tag ) {
        case SJVideoPlayerCenterViewTag_Replay: {
            [_videoPlayer replay];
        }
            break;
        case SJVideoPlayerCenterViewTag_Failed: {
            [_videoPlayer refresh];
        }
            break;
        default:
            break;
    }
}

#pragma mark - Bottom control view
- (SJVideoPlayerBottomControlView *)bottomControlView {
    if ( _bottomControlView ) return _bottomControlView;
    _bottomControlView = [SJVideoPlayerBottomControlView new];
    _bottomControlView.delegate = self;
    return _bottomControlView;
}

- (SJVideoPlayerControlMaskView *)bottomControlMaskView {
    if ( _bottomControlMaskView ) return _bottomControlMaskView;
    _bottomControlMaskView = [[SJVideoPlayerControlMaskView alloc] initWithStyle:SJMaskStyle_bottom];
    return _bottomControlMaskView;
}

- (void)bottomView:(SJVideoPlayerBottomControlView *)view clickedBtnTag:(SJVideoPlayerBottomViewTag)tag {
    switch ( tag ) {
        case SJVideoPlayerBottomViewTag_Play: {
            if ( self.videoPlayer.state == SJVideoPlayerPlayState_PlayEnd ) [self.videoPlayer replay];
            else [self.videoPlayer play];
        }
            break;
        case SJVideoPlayerBottomViewTag_Pause: {
            [self.videoPlayer pauseForUser];
        }
            break;
        case SJVideoPlayerBottomViewTag_Full: {
            [self.videoPlayer rotate];
        }
            break;
    }
}

- (SJVideoPlayerDraggingProgressView *)draggingProgressView {
    if ( _draggingProgressView ) return _draggingProgressView;
    _draggingProgressView = [SJVideoPlayerDraggingProgressView new];
    return _draggingProgressView;
}

- (void)sliderWillBeginDraggingForBottomView:(SJVideoPlayerBottomControlView *)view {
    UIView_Animations(CommonAnimaDuration, ^{
        [self.draggingProgressView appear];
    }, nil);
    [self.draggingProgressView setTimeShiftStr:self.videoPlayer.currentTimeStr totalTimeStr:self.videoPlayer.totalTimeStr];
    [_videoPlayer controlLayerNeedDisappear];
    self.draggingProgressView.playProgress = self.videoPlayer.progress;
    self.draggingProgressView.shiftProgress = self.videoPlayer.progress;
}

- (void)bottomView:(SJVideoPlayerBottomControlView *)view sliderDidDrag:(CGFloat)progress {
    self.draggingProgressView.shiftProgress = progress;
    [self.draggingProgressView setTimeShiftStr:[self.videoPlayer timeStringWithSeconds:self.draggingProgressView.shiftProgress * self.videoPlayer.totalTime]];
    if ( self.videoPlayer.isFullScreen && !self.videoPlayer.URLAsset.isM3u8 ) {
        NSTimeInterval secs = self.draggingProgressView.shiftProgress * self.videoPlayer.totalTime;
        __weak typeof(self) _self = self;
        [self.videoPlayer screenshotWithTime:secs size:CGSizeMake(self.draggingProgressView.frame.size.width * 2, self.draggingProgressView.frame.size.height * 2) completion:^(SJVideoPlayer * _Nonnull videoPlayer, UIImage * _Nullable image, NSError * _Nullable error) {
            __strong typeof(_self) self = _self;
            if ( !self ) return;
            [self.draggingProgressView setPreviewImage:image];
        }];
    }
}

- (void)sliderDidEndDraggingForBottomView:(SJVideoPlayerBottomControlView *)view {
    UIView_Animations(CommonAnimaDuration, ^{
        [self.draggingProgressView disappear];
    }, nil);

    __weak typeof(self) _self = self;
    [self.videoPlayer jumpedToTime:self.draggingProgressView.shiftProgress * self.videoPlayer.totalTime completionHandler:^(BOOL finished) {
        __strong typeof(_self) self = _self;
        if ( !self ) return;
        [self.videoPlayer play];
    }];
}

#pragma mark - Right control view

- (SJVideoPlayerRightControlView *)rightControlView {
    if ( _rightControlView ) return _rightControlView;
    _rightControlView = [SJVideoPlayerRightControlView new];
    _rightControlView.delegate = self;
    _rightControlView.filmEditingBtnImage = self.settings.filmEditingBtnImage;
    return _rightControlView;
}

- (void)rightControlView:(SJVideoPlayerRightControlView *)view clickedBtnTag:(SJVideoPlayerRightViewTag)tag {
    if ( tag == SJVideoPlayerRightViewTag_FilmEditing ) {
        [self _presentFilmEditingControlView];
    }
}

#pragma mark - Right Film Editing

- (void)setEnableFilmEditing:(BOOL)enableFilmEditing {
    if ( enableFilmEditing == _enableFilmEditing ) return;
    _enableFilmEditing = enableFilmEditing;
    if ( enableFilmEditing ) {
        [self.containerView insertSubview:self.rightControlView aboveSubview:self.bottomControlView];
        [_rightControlView mas_makeConstraints:^(MASConstraintMaker *make) {
            make.centerY.offset(0);
            make.trailing.offset(0);
        }];
        _rightControlView.disappearType = SJDisappearType_Transform;
        _rightControlView.disappearTransform = CGAffineTransformMakeTranslation(_rightControlView.intrinsicContentSize.width, 0);
        
        if ( !self.videoPlayer.controlLayerAppeared ) [_rightControlView disappear];
    }
    else {
        [_rightControlView removeFromSuperview];
        _rightControlView = nil;
    }
}

- (SJVideoPlayerRegistrar *)registrar {
    if ( _registrar ) return _registrar;
    _registrar = [SJVideoPlayerRegistrar new];
    __weak typeof(self) _self = self;
    _registrar.willResignActive = ^(SJVideoPlayerRegistrar * _Nonnull registrar) {
        __strong typeof(_self) self = _self;
        if ( !self ) return;
        if ( self.filmEditingControlView.status == SJVideoPlayerFilmEditingStatus_Recording ) {
            [self.filmEditingControlView pause];
            [self.videoPlayer pause];
            [self.videoPlayer controlLayerNeedDisappear];
        }
    };
    
    _registrar.didBecomeActive = ^(SJVideoPlayerRegistrar * _Nonnull registrar) {
        __strong typeof(_self) self = _self;
        if ( !self ) return;
        if ( self.filmEditingControlView.status == SJVideoPlayerFilmEditingStatus_Paused ) {
            [self.filmEditingControlView resume];
            [self.videoPlayer play];
            [self.videoPlayer controlLayerNeedDisappear];
        }
        else if ( self.filmEditingControlView.status == SJVideoPlayerFilmEditingStatus_Cancelled ) {
            [self Extension_pauseAndDeterAppear];
        }
        
    };
    return _registrar;
}

- (UIImage *)playerScreenshot {
    return _videoPlayer.screenshot;
}

- (id<SJVideoPlayerFilmEditing>)filmEditing {
    return (id)self.videoPlayer;
}

- (NSArray<SJFilmEditingResultShareItem *> *)resultShareItems {
    return self.videoPlayer.filmEditingConfig.resultShareItems;
}

- (SJVideoPlayerURLAsset *)currentPalyAsset {
    return self.videoPlayer.URLAsset;
}

- (BOOL)resultNeedUpload {
    return self.videoPlayer.filmEditingConfig.resultNeedUpload;
}

- (CGFloat)operationContainerViewRightOffset {
    return (self.containerView.bounds.size.width - self.bounds.size.width) * 0.5;
}

- (BOOL)shouldStartWhenUserSelectedAnOperation:(SJVideoPlayerFilmEditingOperation)selectedOperation {
    if ( self.videoPlayer.filmEditingConfig.shouldStartWhenUserSelectedAnOperation ) {
        return self.videoPlayer.filmEditingConfig.shouldStartWhenUserSelectedAnOperation(self.videoPlayer, selectedOperation);
    }
    return YES;
}

- (void)_presentFilmEditingControlView {
    [self registrar];
    _filmEditingControlView = [SJVideoPlayerFilmEditingControlView new];
    _filmEditingControlView.dataSource = self;
    _filmEditingControlView.uploader = self.videoPlayer.filmEditingConfig.resultUploader;
    _filmEditingControlView.delegate = self;
    _filmEditingControlView.resource = (id)self.settings;
    _filmEditingControlView.disableScreenshot = self.videoPlayer.filmEditingConfig.disableScreenshot;
    _filmEditingControlView.disableRecord = self.videoPlayer.filmEditingConfig.disableRecord;
    _filmEditingControlView.disableGIF = self.videoPlayer.filmEditingConfig.disableGIF;
    _filmEditingControlView.disappearType = SJDisappearType_Alpha;
    [self addSubview:_filmEditingControlView];
    [_filmEditingControlView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.offset(0);
    }];
    
    [self.videoPlayer controlLayerNeedDisappear];
    [self.bottomSlider disappear];
    if ( self.videoPlayer.state == SJVideoPlayerPlayState_PlayEnd ) [self.centerControlView disappear];
    self.videoPlayer.disableRotation = YES;
    self.videoPlayer.disableGestureTypes = SJDisablePlayerGestureTypes_All;
}

- (void)dismissFilmEditingViewCompletion:(void(^ __nullable)(SJVideoPlayerDefaultControlView *))completion {
    if ( _filmEditingControlView ) {
        UIView_Animations(CommonAnimaDuration, ^{
            [self.filmEditingControlView disappear];
        }, ^{
            self.videoPlayer.disableRotation = self.propertyRecorder.disableRotation;
            self.videoPlayer.disableGestureTypes = self.propertyRecorder.disableGestureTypes;
            [self.videoPlayer play];
            [self.filmEditingControlView removeFromSuperview];
            self.filmEditingControlView = nil;  // clear
            self->_registrar = nil;
            if ( completion ) completion(self);
        });
    }
    else {
        if ( completion ) completion(self);
    }
}

- (void)filmEditingControlView:(SJVideoPlayerFilmEditingControlView *)filmEditingControlView statusChanged:(SJVideoPlayerFilmEditingStatus)status {
    switch ( status ) {
        case SJVideoPlayerFilmEditingStatus_Unknown: break;
        case SJVideoPlayerFilmEditingStatus_Recording: {
            if ( self.videoPlayer.state == SJVideoPlayerPlayState_PlayEnd ) {
                [self.videoPlayer replay];
            }
            else if ( self.videoPlayer.state == SJVideoPlayerPlayState_Paused ) {
                [self.videoPlayer play];
            }
        }
            break;
        case SJVideoPlayerFilmEditingStatus_Cancelled: {
            [self dismissFilmEditingViewCompletion:^(SJVideoPlayerDefaultControlView * _Nonnull view) {
                [self.videoPlayer controlLayerNeedAppear];
            }];
        }
            break;
        case SJVideoPlayerFilmEditingStatus_Paused: {
            [self Extension_pauseAndDeterAppear];
        }
            break;
        case SJVideoPlayerFilmEditingStatus_Finished: {
            [self Extension_pauseAndDeterAppear];
        }
            break;
    }
    
#ifdef DEBUG
    switch ( status ) {
        case SJVideoPlayerFilmEditingStatus_Unknown: break;
        case SJVideoPlayerFilmEditingStatus_Recording: {
            NSLog(@"Recording");
        }
            break;
        case SJVideoPlayerFilmEditingStatus_Cancelled: {
            NSLog(@"Cancelled");
        }
            break;
        case SJVideoPlayerFilmEditingStatus_Paused: {
            NSLog(@"Paused");
        }
            break;
        case SJVideoPlayerFilmEditingStatus_Finished: {
            NSLog(@"Finished");
        }
            break;
    }
#endif
}

- (void)filmEditingControlView:(SJVideoPlayerFilmEditingControlView *)filmEditingControlView userSelectedOperation:(SJVideoPlayerFilmEditingOperation)operation {
    self.videoPlayer.videoGravity = AVLayerVideoGravityResizeAspect;
    switch ( operation ) {
        case SJVideoPlayerFilmEditingOperation_Screenshot: {
            [self Extension_pauseAndDeterAppear];
        }
            break;
        case SJVideoPlayerFilmEditingOperation_GIF:
        case SJVideoPlayerFilmEditingOperation_Export: break;
    }
    
    
#ifdef DEBUG
    switch ( operation ) {
        case SJVideoPlayerFilmEditingOperation_GIF: {
            NSLog(@"User selected Operation: GIF ");
        }
            break;
        case SJVideoPlayerFilmEditingOperation_Export: {
            NSLog(@"User selected Operation: Export ");
        }
            break;
        case SJVideoPlayerFilmEditingOperation_Screenshot: {
            NSLog(@"User selected Operation: Screenshot ");
        }
            break;
    }
#endif
    
}

- (void)filmEditingControlView:(SJVideoPlayerFilmEditingControlView *)filmEditingControlView userClickedResultShareItem:(SJFilmEditingResultShareItem *)item result:(nonnull id<SJVideoPlayerFilmEditingResult>)result {
    if ( self.videoPlayer.filmEditingConfig.clickedResultShareItemExeBlock ) self.videoPlayer.filmEditingConfig.clickedResultShareItemExeBlock(self.videoPlayer, item, result);
}

- (void)userTappedBlankAreaAtFilmEditingControlView:(SJVideoPlayerFilmEditingControlView *)filmEditingControlView {
    [self dismissFilmEditingViewCompletion:^(SJVideoPlayerDefaultControlView * _Nonnull view) {
        [self.videoPlayer controlLayerNeedAppear];
    }];
}

#pragma mark - Bottom slider

- (SJSlider *)bottomSlider {
    if ( _bottomSlider ) return _bottomSlider;
    _bottomSlider = [SJSlider new];
    _bottomSlider.pan.enabled = NO;
    _bottomSlider.trackHeight = 1;
    return _bottomSlider;
}


#pragma mark - 一级`更多`视图
- (SJVideoPlayerMoreSettingsView *)moreSettingsView {
    if ( _moreSettingsView ) return _moreSettingsView;
    _moreSettingsView = [SJVideoPlayerMoreSettingsView new];
    _moreSettingsView.footerViewModel = self.footerViewModel;
    return _moreSettingsView;
}

- (SJMoreSettingsSlidersViewModel *)footerViewModel {
    if ( _footerViewModel ) return _footerViewModel;
    _footerViewModel = [SJMoreSettingsSlidersViewModel new];
    
    __weak typeof(self) _self = self;
    _footerViewModel.initialBrightnessValue = ^float{
        __strong typeof(_self) self = _self;
        if ( !self ) return 0;
        return self.videoPlayer.brightness;
    };
    
    _footerViewModel.initialVolumeValue = ^float{
        __strong typeof(_self) self = _self;
        if ( !self ) return 0;
        return self.videoPlayer.volume;
    };
    
    _footerViewModel.initialPlayerRateValue = ^float{
        __strong typeof(_self) self = _self;
        if ( !self ) return 1;
        return self.videoPlayer.rate;
    };
    
    _footerViewModel.needChangeVolume = ^(float volume) {
        __strong typeof(_self) self = _self;
        if ( !self ) return;
        self.videoPlayer.volume = volume;
    };
    
    _footerViewModel.needChangeBrightness = ^(float brightness) {
        __strong typeof(_self) self = _self;
        if ( !self ) return;
        self.videoPlayer.brightness = brightness;
    };
    
    _footerViewModel.needChangePlayerRate = ^(float rate) {
        __strong typeof(_self) self = _self;
        if ( !self ) return;
        self.videoPlayer.rate = rate;
    };
    return _footerViewModel;
}

- (void)setMoreSettings:(NSArray<SJVideoPlayerMoreSetting *> *)moreSettings {
    if ( moreSettings == _moreSettings ) return;
    _moreSettings = moreSettings;
    NSMutableSet<SJVideoPlayerMoreSetting *> *moreSettingsM = [NSMutableSet new];
    [moreSettings enumerateObjectsUsingBlock:^(SJVideoPlayerMoreSetting * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [self _addSetting:obj container:moreSettingsM];
    }];
    [moreSettingsM enumerateObjectsUsingBlock:^(SJVideoPlayerMoreSetting * _Nonnull obj, BOOL * _Nonnull stop) {
        [self _dressSetting:obj];
    }];
    
    self.moreSettingsView.moreSettings = moreSettings;
}

- (void)_addSetting:(SJVideoPlayerMoreSetting *)setting container:(NSMutableSet<SJVideoPlayerMoreSetting *> *)moreSttingsM {
    [moreSttingsM addObject:setting];
    if ( !setting.showTowSetting ) return;
    [setting.twoSettingItems enumerateObjectsUsingBlock:^(SJVideoPlayerMoreSettingSecondary * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [self _addSetting:(SJVideoPlayerMoreSetting *)obj container:moreSttingsM];
    }];
}

- (void)_dressSetting:(SJVideoPlayerMoreSetting *)setting {
    if ( !setting.clickedExeBlock ) return;
    __weak typeof(self) _self = self;
    if ( setting.isShowTowSetting ) {
        setting._exeBlock = ^(SJVideoPlayerMoreSetting * _Nonnull setting) {
            __strong typeof(_self) self = _self;
            if ( !self ) return;
            if ( !self.moreSecondarySettingView.superview ) {
                [self addSubview:self.moreSecondarySettingView];
                [self.moreSecondarySettingView mas_makeConstraints:^(MASConstraintMaker *make) {
                    make.edges.equalTo(self.moreSettingsView);
                }];
            }
            UIView_Animations(CommonAnimaDuration, ^{
                [self.moreSettingsView disappear];
                [self.moreSecondarySettingView appear];
            }, nil);
            self.moreSecondarySettingView.twoLevelSettings = setting;
            setting.clickedExeBlock(setting);
        };
    }
    else {
        setting._exeBlock = ^(SJVideoPlayerMoreSetting * _Nonnull setting) {
            __strong typeof(_self) self = _self;
            if ( !self ) return;
            UIView_Animations(CommonAnimaDuration, ^{
                [self.moreSettingsView disappear];
                [self.moreSecondarySettingView disappear];
            }, nil);
            setting.clickedExeBlock(setting);
        };
    }
}


#pragma mark - 二级`更多`视图
- (SJVideoPlayerMoreSettingSecondaryView *)moreSecondarySettingView {
    if ( _moreSecondarySettingView ) return _moreSecondarySettingView;
    _moreSecondarySettingView = [SJVideoPlayerMoreSettingSecondaryView new];
    return _moreSecondarySettingView;
}


#pragma mark - Loading view
- (SJLoadingView *)loadingView {
    if ( _loadingView ) return _loadingView;
    _loadingView = [SJLoadingView new];
    __weak typeof(self) _self = self;
    _loadingView.settingRecroder = [[SJVideoPlayerControlSettingRecorder alloc] initWithSettings:^(SJVideoPlayerSettings * _Nonnull setting) {
        __strong typeof(_self) self = _self;
        if ( !self ) return;
        self.loadingView.lineColor = setting.loadingLineColor;
    }];
    return _loadingView;
}


#pragma mark - 加载配置

- (void)_controlViewLoadSetting {
    // load setting
    SJVideoPlayer.update(^(SJVideoPlayerSettings * _Nonnull commonSettings) {});
    
    __weak typeof(self) _self = self;
    self.settingRecroder = [[SJVideoPlayerControlSettingRecorder alloc] initWithSettings:^(SJVideoPlayerSettings * _Nonnull setting) {
        __strong typeof(_self) self = _self;
        if ( !self ) return;
        self.bottomSlider.traceImageView.backgroundColor = setting.progress_traceColor;
        self.bottomSlider.trackImageView.backgroundColor = setting.progress_bufferColor;
        self.videoPlayer.placeholder = setting.placeholder;
        if ( self.enableFilmEditing ) self.rightControlView.filmEditingBtnImage = setting.filmEditingBtnImage;
        [self.draggingProgressView setPreviewImage:setting.placeholder];
        self.settings = setting;
        [self _promptWithNetworkStatus:self.videoPlayer.networkStatus];
    }];
}

#pragma mark -
- (SJTimerControl *)lockStateTappedTimerControl {
    if ( _lockStateTappedTimerControl ) return _lockStateTappedTimerControl;
    _lockStateTappedTimerControl = [[SJTimerControl alloc] init];
    __weak typeof(self) _self = self;
    _lockStateTappedTimerControl.exeBlock = ^(SJTimerControl * _Nonnull control) {
        __strong typeof(_self) self = _self;
        if ( !self ) return;
        [control clear];
        UIView_Animations(CommonAnimaDuration, ^{
            if ( self.leftControlView.appearState ) [self.leftControlView disappear];
        }, nil);
    };
    return _lockStateTappedTimerControl;
}
@end