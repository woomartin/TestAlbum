//
//  ViewController.m
//  TestAlbum
//
//  Created by mm on 2025/11/12.
//

#import "ViewController.h"
#import <Photos/Photos.h>

@interface ViewController () <UICollectionViewDelegate, UICollectionViewDataSource>

@property (nonatomic, strong) UICollectionView *collectionView;
@property (nonatomic, strong) NSArray<PHAsset *> *mediaAssets;
@property (nonatomic, strong) PHCachingImageManager *imageManager;
@property (nonatomic, strong) NSMutableSet<NSString *> *selectedIdentifiers;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.imageManager = [[PHCachingImageManager alloc] init];
    self.selectedIdentifiers = [NSMutableSet set];

    [self setupCollectionView];
    [self requestPhotoLibraryAccess];
}

- (void)setupCollectionView {
    UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
    layout.scrollDirection = UICollectionViewScrollDirectionHorizontal;
    layout.itemSize = CGSizeMake(30, 86);
    layout.minimumInteritemSpacing = 5;
    layout.minimumLineSpacing = 5;

    self.collectionView = [[UICollectionView alloc] initWithFrame:CGRectMake(0, 100, self.view.bounds.size.width, 86) collectionViewLayout:layout];
    self.collectionView.backgroundColor = [UIColor whiteColor];
    self.collectionView.delegate = self;
    self.collectionView.dataSource = self;
    self.collectionView.showsHorizontalScrollIndicator = NO;
    [self.collectionView registerClass:[UICollectionViewCell class] forCellWithReuseIdentifier:@"MediaCell"];

    [self.view addSubview:self.collectionView];
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
                                 targetSize:CGSizeMake(30 * [UIScreen mainScreen].scale, 86 * [UIScreen mainScreen].scale)
                                contentMode:PHImageContentModeAspectFill
                                    options:nil
                              resultHandler:^(UIImage *result, NSDictionary *info) {
        imageView.image = result;
    }];

    // 如果是视频，添加播放图标和时长信息
    if (asset.mediaType == PHAssetMediaTypeVideo) {
        // 播放图标在左下方
        UIImageView *playIcon = [[UIImageView alloc] initWithFrame:CGRectMake(5, 86 - 20 - 5, 20, 20)];
        playIcon.image = [UIImage systemImageNamed:@"play.circle.fill"];
        playIcon.tintColor = [UIColor whiteColor];
        [cell.contentView addSubview:playIcon];

        // 视频时长在右下方
        NSTimeInterval duration = asset.duration;
        NSInteger minutes = (NSInteger)duration / 60;
        NSInteger seconds = (NSInteger)duration % 60;
        NSString *durationString = [NSString stringWithFormat:@"%02ld:%02ld", (long)minutes, (long)seconds];

        UILabel *durationLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 86 - 18 - 3, 30, 18)];
        durationLabel.text = durationString;
        durationLabel.textColor = [UIColor whiteColor];
        durationLabel.font = [UIFont systemFontOfSize:10];
        durationLabel.textAlignment = NSTextAlignmentRight;
        [cell.contentView addSubview:durationLabel];
    }

    // 添加选中按钮到右上方
    UIImageView *selectIcon = [[UIImageView alloc] initWithFrame:CGRectMake(30 - 20 - 3, 3, 20, 20)];
    BOOL isSelected = [self.selectedIdentifiers containsObject:asset.localIdentifier];

    if (isSelected) {
        selectIcon.image = [UIImage systemImageNamed:@"checkmark.circle.fill"];
        selectIcon.tintColor = [UIColor systemBlueColor];
    } else {
        selectIcon.image = [UIImage systemImageNamed:@"circle"];
        selectIcon.tintColor = [UIColor whiteColor];
    }

    [cell.contentView addSubview:selectIcon];

    return cell;
}

#pragma mark - UICollectionViewDelegate

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    PHAsset *asset = self.mediaAssets[indexPath.item];
    NSString *identifier = asset.localIdentifier;

    if ([self.selectedIdentifiers containsObject:identifier]) {
        [self.selectedIdentifiers removeObject:identifier];
    } else {
        [self.selectedIdentifiers addObject:identifier];
    }

    // 刷新对应的 cell
    [self.collectionView reloadItemsAtIndexPaths:@[indexPath]];
}


@end
