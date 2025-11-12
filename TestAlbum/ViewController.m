//
//  ViewController.m
//  TestAlbum
//
//  Created by mm on 2025/11/12.
//

#import "ViewController.h"
#import <Photos/Photos.h>
#import <AVFoundation/AVFoundation.h>

// 媒体信息模型
@interface MediaInfo : NSObject

@property (nonatomic, copy) NSString *identifier;
@property (nonatomic, assign) BOOL isVideo;
@property (nonatomic, assign) NSTimeInterval duration;
@property (nonatomic, assign) NSInteger width;
@property (nonatomic, assign) NSInteger height;
@property (nonatomic, assign) long long size;
@property (nonatomic, copy) NSString *imagePath;  // 图片路径或视频封面路径
@property (nonatomic, copy) NSString *videoPath;  // 视频路径

@end

@implementation MediaInfo
@end

@interface ViewController () <UICollectionViewDelegate, UICollectionViewDataSource>

@property (nonatomic, strong) UICollectionView *collectionView;
@property (nonatomic, strong) NSArray<PHAsset *> *mediaAssets;
@property (nonatomic, strong) PHCachingImageManager *imageManager;
@property (nonatomic, strong) NSMutableArray<MediaInfo *> *selectedMediaList;
@property (nonatomic, strong) UIButton *exportButton;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.imageManager = [[PHCachingImageManager alloc] init];
    self.selectedMediaList = [NSMutableArray array];

    [self setupCollectionView];
    [self setupExportButton];
    [self requestPhotoLibraryAccess];
}

- (void)setupCollectionView {
    UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
    layout.scrollDirection = UICollectionViewScrollDirectionHorizontal;
    layout.itemSize = CGSizeMake(40, 86);
    layout.minimumInteritemSpacing = 5;
    layout.minimumLineSpacing = 5;
    layout.sectionInset = UIEdgeInsetsMake(0, 5, 0, 5);

    self.collectionView = [[UICollectionView alloc] initWithFrame:CGRectMake(0, 100, self.view.bounds.size.width, 86) collectionViewLayout:layout];
    self.collectionView.backgroundColor = [UIColor whiteColor];
    self.collectionView.delegate = self;
    self.collectionView.dataSource = self;
    self.collectionView.showsHorizontalScrollIndicator = NO;
    [self.collectionView registerClass:[UICollectionViewCell class] forCellWithReuseIdentifier:@"MediaCell"];

    [self.view addSubview:self.collectionView];
}

- (void)setupExportButton {
    self.exportButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.exportButton.frame = CGRectMake(20, 200, self.view.bounds.size.width - 40, 50);
    [self.exportButton setTitle:@"导出选中媒体" forState:UIControlStateNormal];
    self.exportButton.backgroundColor = [UIColor systemBlueColor];
    [self.exportButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.exportButton.titleLabel.font = [UIFont boldSystemFontOfSize:16];
    self.exportButton.layer.cornerRadius = 8;
    [self.exportButton addTarget:self action:@selector(exportButtonTapped) forControlEvents:UIControlEventTouchUpInside];

    [self.view addSubview:self.exportButton];
}

- (void)requestPhotoLibraryAccess {
    PHAuthorizationStatus status = [PHPhotoLibrary authorizationStatus];

    if (status == PHAuthorizationStatusAuthorized) {
        [self fetchRecentMedia];
    } else if (status == PHAuthorizationStatusNotDetermined) {
        [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
            if (status == PHAuthorizationStatusAuthorized) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self fetchRecentMedia];
                });
            }
        }];
    }
}

- (void)fetchRecentMedia {
    PHFetchOptions *options = [[PHFetchOptions alloc] init];
    options.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"creationDate" ascending:NO]];
    options.predicate = [NSPredicate predicateWithFormat:@"mediaType = %d OR mediaType = %d", PHAssetMediaTypeImage, PHAssetMediaTypeVideo];
    options.fetchLimit = 30;

    PHFetchResult<PHAsset *> *fetchResult = [PHAsset fetchAssetsWithOptions:options];

    NSMutableArray *assets = [NSMutableArray array];
    [fetchResult enumerateObjectsUsingBlock:^(PHAsset *asset, NSUInteger idx, BOOL *stop) {
        [assets addObject:asset];
    }];

    self.mediaAssets = [assets copy];
    [self.collectionView reloadData];
}

#pragma mark - Helper Methods

- (void)exportButtonTapped {
    if (self.selectedMediaList.count == 0) {
        NSLog(@"没有选中任何媒体");
        return;
    }

    NSLog(@"开始导出 %ld 个媒体...", (long)self.selectedMediaList.count);

    [self exportSelectedMediaList:self.selectedMediaList completion:^(NSArray<MediaInfo *> *mediaList) {

        NSLog(@"导出成功！共导出 %ld 个文件", (long)mediaList.count);
        NSLog(@"========== 导出数据详情 ==========");

        for (NSInteger i = 0; i < mediaList.count; i++) {
            MediaInfo *info = mediaList[i];
            NSLog(@"\n[%ld] 媒体信息:", (long)(i + 1));
            NSLog(@"  类型: %@", info.isVideo ? @"视频" : @"图片");
            NSLog(@"  Identifier: %@", info.identifier);
            NSLog(@"  尺寸: %ldx%ld", (long)info.width, (long)info.height);
            NSLog(@"  文件大小: %.2f MB", info.size / 1024.0 / 1024.0);

            if (info.isVideo) {
                NSLog(@"  时长: %.2f 秒", info.duration);
                NSLog(@"  视频路径: %@", info.videoPath);
                NSLog(@"  封面路径: %@", info.imagePath);
            } else {
                NSLog(@"  图片路径: %@", info.imagePath);
            }
        }

        NSLog(@"\n========== 导出完成 ==========");
    }];
}

// 导出图片数据到文件的辅助方法
- (void)exportImageDataForAsset:(PHAsset *)asset
                      toPath:(NSString *)filePath
                 completion:(void(^)(NSString *path, NSError *error))completion {
    PHImageRequestOptions *options = [[PHImageRequestOptions alloc] init];
    options.deliveryMode = PHImageRequestOptionsDeliveryModeFastFormat;
    options.networkAccessAllowed = YES;

    [[PHImageManager defaultManager] requestImageDataForAsset:asset options:options resultHandler:^(NSData *imageData, NSString *dataUTI, UIImageOrientation orientation, NSDictionary *info) {
        if (imageData) {
            NSError *error = nil;
            if ([imageData writeToFile:filePath options:NSDataWritingAtomic error:&error]) {
                completion(filePath, nil);
            } else {
                completion(nil, error);
            }
        } else {
            completion(nil, nil);
        }
    }];
}

- (MediaInfo *)createMediaInfoFromAsset:(PHAsset *)asset {
    MediaInfo *info = [[MediaInfo alloc] init];
    info.identifier = asset.localIdentifier;
    info.isVideo = (asset.mediaType == PHAssetMediaTypeVideo);
    info.duration = asset.duration;
    info.width = asset.pixelWidth;
    info.height = asset.pixelHeight;

    // 获取文件大小
    PHAssetResource *resource = [[PHAssetResource assetResourcesForAsset:asset] firstObject];
    info.size = [[resource valueForKey:@"fileSize"] longLongValue];

    return info;
}

- (MediaInfo *)findMediaInfoByIdentifier:(NSString *)identifier {
    for (MediaInfo *info in self.selectedMediaList) {
        if ([info.identifier isEqualToString:identifier]) {
            return info;
        }
    }
    return nil;
}

- (BOOL)isMediaSelected:(NSString *)identifier {
    return [self findMediaInfoByIdentifier:identifier] != nil;
}

#pragma mark - UICollectionViewDataSource

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return self.mediaAssets.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    UICollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"MediaCell" forIndexPath:indexPath];

    // 清理之前的 imageView
    for (UIView *subview in cell.contentView.subviews) {
        [subview removeFromSuperview];
    }

    PHAsset *asset = self.mediaAssets[indexPath.item];

    UIImageView *imageView = [[UIImageView alloc] initWithFrame:cell.contentView.bounds];
    imageView.contentMode = UIViewContentModeScaleAspectFill;
    imageView.clipsToBounds = YES;
    [cell.contentView addSubview:imageView];

    // 请求缩略图
    [self.imageManager requestImageForAsset:asset
                                 targetSize:CGSizeMake(40 * [UIScreen mainScreen].scale, 86 * [UIScreen mainScreen].scale)
                                contentMode:PHImageContentModeAspectFill
                                    options:nil
                              resultHandler:^(UIImage *result, NSDictionary *info) {
        imageView.image = result;
    }];

    // 如果是视频，添加播放图标和时长信息
    if (asset.mediaType == PHAssetMediaTypeVideo) {
        // 底部对齐的基准位置
        CGFloat bottomY = 86 - 2;  // 距离底边2点
        CGFloat elementHeight = 12;  // 统一高度

        // 播放图标在左下方
        UIImageView *playIcon = [[UIImageView alloc] initWithFrame:CGRectMake(3, bottomY - elementHeight, 12, 12)];
        playIcon.image = [UIImage systemImageNamed:@"play.circle.fill"];
        playIcon.tintColor = [UIColor whiteColor];
        [cell.contentView addSubview:playIcon];

        // 视频时长在右下方
        NSTimeInterval duration = asset.duration;
        NSInteger minutes = (NSInteger)duration / 60;
        NSInteger seconds = (NSInteger)duration % 60;
        NSString *durationString = [NSString stringWithFormat:@"%02ld:%02ld", (long)minutes, (long)seconds];

        UILabel *durationLabel = [[UILabel alloc] initWithFrame:CGRectMake(15, bottomY - elementHeight, 40 - 15, elementHeight)];
        durationLabel.text = durationString;
        durationLabel.textColor = [UIColor whiteColor];
        durationLabel.font = [UIFont systemFontOfSize:9];
        durationLabel.textAlignment = NSTextAlignmentRight;
        [cell.contentView addSubview:durationLabel];
    }

    // 添加选中标识到右上方
    MediaInfo *selectedInfo = [self findMediaInfoByIdentifier:asset.localIdentifier];

    if (selectedInfo) {
        // 已选中，显示序号
        NSInteger selectedIndex = [self.selectedMediaList indexOfObject:selectedInfo];
        NSInteger orderNumber = selectedIndex + 1;

        // 创建圆形背景
        UIView *circleView = [[UIView alloc] initWithFrame:CGRectMake(40 - 20 - 3, 3, 20, 20)];
        circleView.backgroundColor = [UIColor systemBlueColor];
        circleView.layer.cornerRadius = 10;
        circleView.clipsToBounds = YES;
        [cell.contentView addSubview:circleView];

        // 创建序号标签
        UILabel *numberLabel = [[UILabel alloc] initWithFrame:circleView.bounds];
        numberLabel.text = [NSString stringWithFormat:@"%ld", (long)orderNumber];
        numberLabel.textColor = [UIColor whiteColor];
        numberLabel.font = [UIFont boldSystemFontOfSize:12];
        numberLabel.textAlignment = NSTextAlignmentCenter;
        [circleView addSubview:numberLabel];
    } else {
        // 未选中，显示空心圆圈
        UIImageView *selectIcon = [[UIImageView alloc] initWithFrame:CGRectMake(40 - 20 - 3, 3, 20, 20)];
        selectIcon.image = [UIImage systemImageNamed:@"circle"];
        selectIcon.tintColor = [UIColor whiteColor];
        [cell.contentView addSubview:selectIcon];
    }

    return cell;
}

#pragma mark - UICollectionViewDelegate

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    PHAsset *asset = self.mediaAssets[indexPath.item];
    NSString *identifier = asset.localIdentifier;

    MediaInfo *existingInfo = [self findMediaInfoByIdentifier:identifier];

    // sendEvent到C++层
    if (existingInfo) {
        // 已选中，取消选中
        [self.selectedMediaList removeObject:existingInfo];
    } else {
        // 未选中，添加到选中列表
        MediaInfo *mediaInfo = [self createMediaInfoFromAsset:asset];
        [self.selectedMediaList addObject:mediaInfo];
    }

    // 需要刷新的indexPath列表
    NSMutableArray<NSIndexPath *> *indexPathsToReload = [NSMutableArray arrayWithObject:indexPath];

    // 如果是取消选中操作，需要刷新所有已选中的item以更新序号
    if (existingInfo) {
        for (NSInteger i = 0; i < self.mediaAssets.count; i++) {
            PHAsset *asset = self.mediaAssets[i];
            if ([self isMediaSelected:asset.localIdentifier] && i != indexPath.item) {
                [indexPathsToReload addObject:[NSIndexPath indexPathForItem:i inSection:0]];
            }
        }
    }

    // 刷新所有需要更新的 cell
    [self.collectionView reloadItemsAtIndexPaths:indexPathsToReload];
}

#pragma mark - Public Methods

// C++ updateVO 调用这个函数刷新数据
- (void)updateSelectedMediaList:(NSMutableArray<MediaInfo *> *)selectedList {
    if (!selectedList) {
        self.selectedMediaList = [NSMutableArray array];
    } else {
        self.selectedMediaList = selectedList;
    }

    // 刷新整个 collectionView 以更新所有选中状态和序号
    [self.collectionView reloadData];
}

- (void)exportSelectedMediaList:(NSMutableArray<MediaInfo *> *)selectedList completion:(void(^)(NSArray<MediaInfo *> *mediaList))completion {
    if (!completion) return;

    if (selectedList.count == 0) {
        completion(@[]);
        return;
    }

    // 创建导出目录
    NSString *documentsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    NSString *exportPath = [documentsPath stringByAppendingPathComponent:@"ExportedMedia"];

    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:exportPath]) {
        [fileManager createDirectoryAtPath:exportPath withIntermediateDirectories:YES attributes:nil error:nil];
    }

    dispatch_group_t group = dispatch_group_create();
    __block NSError *exportError = nil;

    for (NSInteger i = 0; i < selectedList.count; i++) {
        MediaInfo *mediaInfo = selectedList[i];

        // 根据 identifier 找到对应的 PHAsset
        PHFetchResult<PHAsset *> *result = [PHAsset fetchAssetsWithLocalIdentifiers:@[mediaInfo.identifier] options:nil];
        if (result.count == 0) continue;

        PHAsset *asset = result.firstObject;

        // 使用 identifier 的 hash 值作为文件名
        NSUInteger hashValue = [mediaInfo.identifier hash];

        if (mediaInfo.isVideo) {
            // 导出视频
            NSString *fileName = [NSString stringWithFormat:@"%luvideo", (unsigned long)hashValue];
            NSString *filePath = [exportPath stringByAppendingPathComponent:fileName];

            dispatch_group_enter(group);

            PHVideoRequestOptions *options = [[PHVideoRequestOptions alloc] init];
            options.deliveryMode = PHVideoRequestOptionsDeliveryModeFastFormat;
            options.networkAccessAllowed = YES;

            [[PHImageManager defaultManager] requestAVAssetForVideo:asset options:options resultHandler:^(AVAsset *avAsset, AVAudioMix *audioMix, NSDictionary *info) {
                if ([avAsset isKindOfClass:[AVURLAsset class]]) {
                    AVURLAsset *urlAsset = (AVURLAsset *)avAsset;
                    NSError *error = nil;

                    // 删除已存在的文件
                    if ([[NSFileManager defaultManager] fileExistsAtPath:filePath]) {
                        [[NSFileManager defaultManager] removeItemAtPath:filePath error:nil];
                    }

                    // 拷贝视频文件
                    if ([[NSFileManager defaultManager] copyItemAtURL:urlAsset.URL toURL:[NSURL fileURLWithPath:filePath] error:&error]) {
                        // 保存路径到 MediaInfo
                        mediaInfo.videoPath = filePath;
                    } else {
                        exportError = error;
                    }
                }
                dispatch_group_leave(group);
            }];
        }
        // 导出图片
        NSString *fileName = [NSString stringWithFormat:@"%luimg", (unsigned long)hashValue];
        NSString *filePath = [exportPath stringByAppendingPathComponent:fileName];

        dispatch_group_enter(group);

        PHImageRequestOptions *options = [[PHImageRequestOptions alloc] init];
        options.deliveryMode = PHImageRequestOptionsDeliveryModeFastFormat;
        options.networkAccessAllowed = YES;

        [[PHImageManager defaultManager] requestImageDataForAsset:asset options:options resultHandler:^(NSData *imageData, NSString *dataUTI, UIImageOrientation orientation, NSDictionary *info) {
            if (imageData) {
                NSError *error = nil;
                if ([imageData writeToFile:filePath options:NSDataWritingAtomic error:&error]) {
                    // 保存路径到 MediaInfo
                    mediaInfo.imagePath = filePath;
                } else {
                    exportError = error;
                }
            }
            dispatch_group_leave(group);
        }];
    }

    // 所有导出任务完成后回调
    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        completion([selectedList copy]);
    });
}


@end
