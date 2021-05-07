// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

interface IQNFTSettings {
    function favCoinsCount() external view returns (uint256);

    function mintOptionsCount() external view returns (uint256);

    function nftImagesCount() external view returns (uint256);

    function bgImagesCount() external view returns (uint256);

    function nftImageMintPrice(uint256 _nftImageId)
        external
        view
        returns (uint256);

    function favCoinMintPrice(uint256 _favCoinId)
        external
        view
        returns (uint256);

    function mintOptionLockDuration(uint256 _mintOptionId)
        external
        view
        returns (uint256);

    function calcMintPrice(
        uint256 _imageId,
        uint256 _bgImageId,
        uint256 _favCoinId,
        uint256 _mintOptionId,
        uint256 _mintAmount,
        uint256 _freeAmount
    ) external view returns (uint256);
}
