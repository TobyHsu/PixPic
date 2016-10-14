//
//  StickersPickerCustomLayout.swift
//  PixPic
//
//  Created by AndrewPetrov on 8/25/16.
//  Copyright © 2016 Yalantis. All rights reserved.
//

import Foundation

private let headersBasicZIndex = 1000
private let cellsBasicZIndex = 100

class StickersPickerCustomLayout: UICollectionViewLayout {

    fileprivate let currentGroupIndex: Int?
    fileprivate let leftStickersCount: Int
    fileprivate let headersNeededToChangeOrderCount: Int
    fileprivate let animationState: AnimationState

    init(animationState: AnimationState, currentGroupIndex: Int?, changeOrderHeadersCount: Int, leftStickersCount: Int) {
        self.animationState = animationState
        self.currentGroupIndex = currentGroupIndex
        self.headersNeededToChangeOrderCount = changeOrderHeadersCount
        self.leftStickersCount = leftStickersCount

        super.init()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        var itemsInRect = [UICollectionViewLayoutAttributes]()
        var headersInRect = [UICollectionViewLayoutAttributes]()
        for sectionIndex in 0..<collectionView!.numberOfSections {
            guard let attribute =
                layoutAttributesForSupplementaryView(ofKind: UICollectionElementKindSectionHeader,
                                                     at: IndexPath(item: 0, section: sectionIndex)) else {
                                                            return nil
            }
            headersInRect.append(attribute)
            for itemIndex in 0..<(collectionView!.numberOfItems(inSection: sectionIndex)) {
                let indexPath = IndexPath(item: itemIndex, section: sectionIndex)
                
                guard let attribute = layoutAttributesForItem(at: indexPath) else {
                    return nil
                }
                itemsInRect.append(attribute)
            }
        }

        return itemsInRect + headersInRect
    }

    override func layoutAttributesForSupplementaryView(ofKind elementKind: String, at indexPath: IndexPath) ->
        UICollectionViewLayoutAttributes? {
            let attributes = UICollectionViewLayoutAttributes(forSupplementaryViewOfKind: elementKind,
                                                              with: indexPath)
            attributes.frame.size = Constants.StickerCell.size
            //every further header covers previous when interrupting
            attributes.zIndex = headersBasicZIndex + indexPath.section

            func isChangingOrderNeededForHeader() -> Bool {
                guard let currentGroupIndex = currentGroupIndex else {
                    return false
                }
                return indexPath.section < currentGroupIndex &&
                    indexPath.section >= currentGroupIndex - headersNeededToChangeOrderCount
            }

            func isCurrentGroupIndex() -> Bool {
                return indexPath.section == currentGroupIndex
            }

            switch animationState {
            case .sectionsInOrder:
                attributes.frame.origin = cellOriginFor(xPosition: indexPath.section, yPosition: 0)

            case .selectedSectionFirst:
                guard let currentGroupIndex = currentGroupIndex else {
                    return nil
                }
                if isCurrentGroupIndex() {
                    attributes.frame.origin = cellOriginFor(xPosition: 0, yPosition: 0)
                } else if isChangingOrderNeededForHeader() {
                    attributes.frame.origin = cellOriginFor(xPosition: indexPath.section - currentGroupIndex +
                        headersNeededToChangeOrderCount + 1, yPosition: 0)
                } else {
                    attributes.frame.origin = cellOriginFor(xPosition: indexPath.section - currentGroupIndex +
                        headersNeededToChangeOrderCount, yPosition: 0)
                }

            case .notSelectedSectionsAbowe, .stickyHeaderWithItems:
                guard let currentGroupIndex = currentGroupIndex else {
                    return nil
                }
                if isCurrentGroupIndex() {
                    if animationState == .notSelectedSectionsAbowe {
                        attributes.frame.origin = cellOriginFor(xPosition: 0, yPosition: 0)
                    } else {
                        attributes.frame.origin = CGPoint(x: collectionView!.contentOffset.x, y: 0)
                    }
                } else if isChangingOrderNeededForHeader() {
                    attributes.frame.origin = cellOriginFor(xPosition: indexPath.section - currentGroupIndex +
                        headersNeededToChangeOrderCount + 1, yPosition: -1)
                } else {
                    attributes.frame.origin = cellOriginFor(xPosition: indexPath.section - currentGroupIndex +
                        headersNeededToChangeOrderCount, yPosition: -1)
                }
            }

            return attributes
    }

    override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        let cellSize = Constants.StickerCell.size

        let attributes = UICollectionViewLayoutAttributes(forCellWith: indexPath)
        attributes.zIndex = cellsBasicZIndex
        attributes.frame.size = cellSize

        func isCurrentGroupIndex() -> Bool {
            return indexPath.section == currentGroupIndex
        }

        switch animationState {
        case .sectionsInOrder:
            attributes.frame.origin = cellOriginFor(xPosition: indexPath.section, yPosition: 1)

        case .selectedSectionFirst:
            if isCurrentGroupIndex() {
                attributes.frame.origin = cellOriginFor(xPosition: indexPath.row + 1 - leftStickersCount, yPosition: 1)
            } else {
                attributes.frame.origin = cellOriginFor(xPosition: 0, yPosition: 1)
            }

        case .notSelectedSectionsAbowe:
            if isCurrentGroupIndex() {
                attributes.frame.origin = cellOriginFor(xPosition: indexPath.row + 1 - leftStickersCount, yPosition: 0)
            } else {
                attributes.frame.origin = cellOriginFor(xPosition: 0, yPosition: 1)
            }

        case .stickyHeaderWithItems:
            if isCurrentGroupIndex() {
                attributes.frame.origin = cellOriginFor(xPosition: indexPath.row + 1, yPosition: 0)
            } else {
                attributes.frame.origin = cellOriginFor(xPosition: -1, yPosition: 0)
            }
        }

        return attributes
    }
    override var collectionViewContentSize: CGSize {
        let size: CGSize
        
        switch animationState {
        case .sectionsInOrder:
            size = contentSize(collectionView!.numberOfSections)
            
        case .selectedSectionFirst, .notSelectedSectionsAbowe:
            let cellsOnScreen = Int(ceil(collectionView!.frame.width / Constants.StickerCell.size.width))
            size = contentSize(cellsOnScreen)
            
        case .stickyHeaderWithItems:
            guard let currentGroupIndex = currentGroupIndex else {
                return CGSize.zero
            }
            size = contentSize(collectionView!.numberOfItems(inSection: currentGroupIndex) + 1)
        }
        
        return size

    }

    override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
        return true
    }

    override func targetContentOffset(forProposedContentOffset proposedContentOffset: CGPoint) -> CGPoint {
        guard animationState == .sectionsInOrder,
            let currentGroupIndex = currentGroupIndex else {
                return CGPoint.zero
        }

        return cellOriginFor(xPosition: currentGroupIndex, yPosition: 0)
    }

    fileprivate func cellOriginFor(xPosition: Int, yPosition: Int) -> CGPoint {
        let cellSize = Constants.StickerCell.size

        return CGPoint(x: cellSize.width * CGFloat(xPosition), y: cellSize.height * CGFloat(yPosition))
    }

    fileprivate func contentSize(_ widthMultiplier: Int) -> CGSize {
        let cellSize = Constants.StickerCell.size

        return CGSize(width: cellSize.width * CGFloat(widthMultiplier), height: cellSize.height)
    }

}
