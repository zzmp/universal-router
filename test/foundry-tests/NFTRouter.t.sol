// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import "forge-std/Test.sol";
import {NFTMarketplaceRouter} from "contracts/modules/NFTMarketplaceRouter.sol";
import {MockMarketplace, MockedMarketplace} from "test/foundry-tests/mocks/MockMarketplace.sol";
import {MockERC721} from "test/foundry-tests/mocks/MockERC721.sol";

contract NFTMarketplaceRouterTest is Test {
    event Purchased(uint256 amount, MockedMarketplace marketplace, uint256 tokenId, address collectionAddress);

    NFTMarketplaceRouter router;
    MockMarketplace seaport;
    MockMarketplace x2y2;
    MockMarketplace looksRare;

    MockERC721 token;

    uint256 internal alicePk = 0xa11ce;
    address payable internal alice = payable(vm.addr(alicePk));

    address private constant SEAPORT_ADDRESS =
        0x00000000006c3852cbEf3e08E8dF289169EdE581;
    address private constant X2Y2_ADDRESS =
        0x74312363e45DCaBA76c59ec49a7Aa8A65a67EeD3;
    address private constant LOOKSRARE_ADDRESS =
        0x59728544B08AB483533076417FbBB2fD0B17CE3a;

    function setUp() public {
        deployContracts();
        deal();
    }

    function deployContracts() internal {
        router = new NFTMarketplaceRouter();

        seaport = new MockMarketplace();
        x2y2 = new MockMarketplace();
        looksRare = new MockMarketplace();

        token = new MockERC721("Token", "TKN");

        vm.etch(SEAPORT_ADDRESS, address(seaport).code);
        vm.etch(X2Y2_ADDRESS, address(x2y2).code);
        vm.etch(LOOKSRARE_ADDRESS, address(looksRare).code);

       MockMarketplace(SEAPORT_ADDRESS).setMarketplace(MockedMarketplace.SEAPORT); 
       MockMarketplace(X2Y2_ADDRESS).setMarketplace(MockedMarketplace.X2Y2); 
       MockMarketplace(LOOKSRARE_ADDRESS).setMarketplace(MockedMarketplace.LOOKSRARE); 
    }

    function deal() internal {
        vm.deal(alice, 100 ether);
        vm.label(alice, "ALICE");

        token.bulkMint(SEAPORT_ADDRESS, 0, 50);
        token.bulkMint(X2Y2_ADDRESS, 50, 25);
        token.bulkMint(LOOKSRARE_ADDRESS, 75, 25);
    }

    /*//////////////////////////////////////////////////////////////
                              YUL-BASED TESTS
    //////////////////////////////////////////////////////////////*/

    function testSingleBuys() public {
        bytes memory seaportCalldata = abi.encodeWithSelector(seaport.seaportPurchase.selector, 0, address(token), alice);
        NFTMarketplaceRouter.PurchaseParameters memory seaportParameters = NFTMarketplaceRouter.PurchaseParameters(
            5 ether,
            NFTMarketplaceRouter.Marketplace.LooksRare,
            0,
            address(token),
            seaportCalldata
        );
        
        NFTMarketplaceRouter.PurchaseParameters[] memory parameters = new NFTMarketplaceRouter.PurchaseParameters[](1);
        parameters[0] = seaportParameters;
        vm.expectEmit(false, false, false, true);
        emit Purchased(5 ether, MockedMarketplace.SEAPORT, 0, address(token));
        vm.prank(alice);
        router.purchase{value: 5 ether}(NFTMarketplaceRouter.OrderType.SEAPORT, parameters);

        bytes memory x2y2Calldata = abi.encodeWithSelector(x2y2.l2r2Purchase.selector, 50, address(token));
        NFTMarketplaceRouter.PurchaseParameters memory x2y2Parameters = NFTMarketplaceRouter.PurchaseParameters(
            5 ether,
            NFTMarketplaceRouter.Marketplace.X2Y2,
            50,
            address(token),
            x2y2Calldata
        );
        
        parameters[0] = x2y2Parameters;
        
        vm.expectEmit(false, false, false, true);
        emit Purchased(5 ether, MockedMarketplace.X2Y2, 50, address(token));
        vm.prank(alice);
        router.purchase{value: 5 ether}(NFTMarketplaceRouter.OrderType.L2R2, parameters);

        bytes memory looksRareCalldata = abi.encodeWithSelector(looksRare.l2r2Purchase.selector, 75, address(token));
        NFTMarketplaceRouter.PurchaseParameters memory looksRareParameters = NFTMarketplaceRouter.PurchaseParameters(
            5 ether,
            NFTMarketplaceRouter.Marketplace.LooksRare,
            75,
            address(token),
            looksRareCalldata
        );
        
        parameters[0] = looksRareParameters;
        
        vm.expectEmit(false, false, false, true);
        emit Purchased(5 ether, MockedMarketplace.LOOKSRARE, 75, address(token));
        vm.prank(alice);
        router.purchase{value: 5 ether}(NFTMarketplaceRouter.OrderType.L2R2, parameters);
        
        assertEq(token.ownerOf(0), alice);
        assertEq(token.ownerOf(50), alice);
        assertEq(token.ownerOf(75), alice);
        assertEq(alice.balance, 85 ether);
    }

    function testBuysAcrossAllMarketplaces() public {
        NFTMarketplaceRouter.PurchaseParameters[] memory parameters = new NFTMarketplaceRouter.PurchaseParameters[](3);

        bytes memory seaportCalldata = abi.encodeWithSelector(seaport.seaportPurchase.selector, 0, address(token), alice);
        NFTMarketplaceRouter.PurchaseParameters memory seaportParameters = NFTMarketplaceRouter.PurchaseParameters(
            5 ether,
            NFTMarketplaceRouter.Marketplace.LooksRare,
            0,
            address(token),
            seaportCalldata
        );
        
        parameters[0] = seaportParameters;
        
        bytes memory x2y2Calldata = abi.encodeWithSelector(x2y2.l2r2Purchase.selector, 50, address(token));
        NFTMarketplaceRouter.PurchaseParameters memory x2y2Parameters = NFTMarketplaceRouter.PurchaseParameters(
            5 ether,
            NFTMarketplaceRouter.Marketplace.X2Y2,
            50,
            address(token),
            x2y2Calldata
        );
        
        parameters[1] = x2y2Parameters;

        bytes memory looksRareCalldata = abi.encodeWithSelector(looksRare.l2r2Purchase.selector, 75, address(token));
        NFTMarketplaceRouter.PurchaseParameters memory looksRareParameters = NFTMarketplaceRouter.PurchaseParameters(
            5 ether,
            NFTMarketplaceRouter.Marketplace.LooksRare,
            75,
            address(token),
            looksRareCalldata
        );
        
        parameters[2] = looksRareParameters;
        
        vm.prank(alice);
        router.purchase{value: 15 ether}(NFTMarketplaceRouter.OrderType.BOTH, parameters);
        
        assertEq(token.ownerOf(0), alice);
        assertEq(token.ownerOf(50), alice);
        assertEq(token.ownerOf(75), alice);
        assertEq(alice.balance, 85 ether);
    }

    function testOnlyL2R2Buys() public {
        NFTMarketplaceRouter.PurchaseParameters[] memory parameters = new NFTMarketplaceRouter.PurchaseParameters[](2);

        bytes memory x2y2Calldata = abi.encodeWithSelector(x2y2.l2r2Purchase.selector, 50, address(token));
        NFTMarketplaceRouter.PurchaseParameters memory x2y2Parameters = NFTMarketplaceRouter.PurchaseParameters(
            5 ether,
            NFTMarketplaceRouter.Marketplace.X2Y2,
            50,
            address(token),
            x2y2Calldata
        );
        
        parameters[0] = x2y2Parameters;

        bytes memory looksRareCalldata = abi.encodeWithSelector(looksRare.l2r2Purchase.selector, 75, address(token));
        NFTMarketplaceRouter.PurchaseParameters memory looksRareParameters = NFTMarketplaceRouter.PurchaseParameters(
            5 ether,
            NFTMarketplaceRouter.Marketplace.LooksRare,
            75,
            address(token),
            looksRareCalldata
        );
        
        parameters[1] = looksRareParameters;
        
        vm.prank(alice);
        router.purchase{value: 10 ether}(NFTMarketplaceRouter.OrderType.L2R2, parameters);
        
        assertEq(token.ownerOf(50), alice);
        assertEq(token.ownerOf(75), alice);
        assertEq(alice.balance, 90 ether);
    }

    function testOnlyX2Y2Buys() public {
        NFTMarketplaceRouter.PurchaseParameters[] memory parameters = new NFTMarketplaceRouter.PurchaseParameters[](3);

        bytes memory x2y2Calldata1 = abi.encodeWithSelector(x2y2.l2r2Purchase.selector, 50, address(token));
        NFTMarketplaceRouter.PurchaseParameters memory x2y2Parameters1 = NFTMarketplaceRouter.PurchaseParameters(
            5 ether,
            NFTMarketplaceRouter.Marketplace.X2Y2,
            50,
            address(token),
            x2y2Calldata1
        );
        
        parameters[0] = x2y2Parameters1;

        bytes memory x2y2Calldata2 = abi.encodeWithSelector(x2y2.l2r2Purchase.selector, 51, address(token));
        NFTMarketplaceRouter.PurchaseParameters memory x2y2Parameters2 = NFTMarketplaceRouter.PurchaseParameters(
            5 ether,
            NFTMarketplaceRouter.Marketplace.X2Y2,
            51,
            address(token),
            x2y2Calldata2
        );
        
        parameters[1] = x2y2Parameters2;

        bytes memory x2y2Calldata3 = abi.encodeWithSelector(x2y2.l2r2Purchase.selector, 52, address(token));
        NFTMarketplaceRouter.PurchaseParameters memory x2y2Parameters3 = NFTMarketplaceRouter.PurchaseParameters(
            5 ether,
            NFTMarketplaceRouter.Marketplace.X2Y2,
            52,
            address(token),
            x2y2Calldata3
        );
        
        parameters[2] = x2y2Parameters3;
        
        vm.prank(alice);
        router.purchase{value: 15 ether}(NFTMarketplaceRouter.OrderType.L2R2, parameters);
        
        assertEq(token.ownerOf(50), alice);
        assertEq(token.ownerOf(51), alice);
        assertEq(token.ownerOf(52), alice);
        assertEq(alice.balance, 85 ether);
    }

    function testOnlyLooksRareBuys() public {
        NFTMarketplaceRouter.PurchaseParameters[] memory parameters = new NFTMarketplaceRouter.PurchaseParameters[](3);

        bytes memory looksRareCalldata1 = abi.encodeWithSelector(looksRare.l2r2Purchase.selector, 75, address(token));
        NFTMarketplaceRouter.PurchaseParameters memory looksRareParameters1 = NFTMarketplaceRouter.PurchaseParameters(
            5 ether,
            NFTMarketplaceRouter.Marketplace.LooksRare,
            75,
            address(token),
            looksRareCalldata1
        );
        
        parameters[0] = looksRareParameters1;

        bytes memory looksRareCalldata2 = abi.encodeWithSelector(looksRare.l2r2Purchase.selector, 76, address(token));
        NFTMarketplaceRouter.PurchaseParameters memory looksRareParameters2 = NFTMarketplaceRouter.PurchaseParameters(
            5 ether,
            NFTMarketplaceRouter.Marketplace.LooksRare,
            76,
            address(token),
            looksRareCalldata2
        );
        
        parameters[1] = looksRareParameters2;

        bytes memory looksRareCalldata3 = abi.encodeWithSelector(looksRare.l2r2Purchase.selector, 77, address(token));
        NFTMarketplaceRouter.PurchaseParameters memory looksRareParameters3 = NFTMarketplaceRouter.PurchaseParameters(
            5 ether,
            NFTMarketplaceRouter.Marketplace.LooksRare,
            77,
            address(token),
            looksRareCalldata3
        );
        
        parameters[2] = looksRareParameters3;
        
        vm.prank(alice);
        router.purchase{value: 15 ether}(NFTMarketplaceRouter.OrderType.L2R2, parameters);
        
        assertEq(token.ownerOf(75), alice);
        assertEq(token.ownerOf(76), alice);
        assertEq(token.ownerOf(77), alice);
        assertEq(alice.balance, 85 ether);
    }

    function testOneBuyTwoRefund() public {
        NFTMarketplaceRouter.PurchaseParameters[] memory parameters = new NFTMarketplaceRouter.PurchaseParameters[](3);

        bytes memory seaportCalldata = abi.encodeWithSelector(seaport.seaportPurchase.selector, 0, address(token), alice);
        NFTMarketplaceRouter.PurchaseParameters memory seaportParameters = NFTMarketplaceRouter.PurchaseParameters(
            5 ether,
            NFTMarketplaceRouter.Marketplace.LooksRare,
            0,
            address(token),
            seaportCalldata
        );
        
        parameters[0] = seaportParameters;
        
        bytes memory x2y2Calldata = abi.encodeWithSelector(x2y2.failPurchase.selector);
        NFTMarketplaceRouter.PurchaseParameters memory x2y2Parameters = NFTMarketplaceRouter.PurchaseParameters(
            5 ether,
            NFTMarketplaceRouter.Marketplace.X2Y2,
            50,
            address(token),
            x2y2Calldata
        );
        
        parameters[1] = x2y2Parameters;

        bytes memory looksRareCalldata = abi.encodeWithSelector(looksRare.failPurchase.selector);
        NFTMarketplaceRouter.PurchaseParameters memory looksRareParameters = NFTMarketplaceRouter.PurchaseParameters(
            5 ether,
            NFTMarketplaceRouter.Marketplace.LooksRare,
            75,
            address(token),
            looksRareCalldata
        );
        
        parameters[2] = looksRareParameters;
        
        vm.prank(alice);
        router.purchase{value: 15 ether}(NFTMarketplaceRouter.OrderType.BOTH, parameters);
        
        assertEq(token.ownerOf(0), alice);
        assertEq(alice.balance, 95 ether);
    }

    function testThreeFailShouldRevert() public {
        NFTMarketplaceRouter.PurchaseParameters[] memory parameters = new NFTMarketplaceRouter.PurchaseParameters[](3);

        bytes memory seaportCalldata = abi.encodeWithSelector(seaport.failPurchase.selector);
        NFTMarketplaceRouter.PurchaseParameters memory seaportParameters = NFTMarketplaceRouter.PurchaseParameters(
            5 ether,
            NFTMarketplaceRouter.Marketplace.LooksRare,
            0,
            address(token),
            seaportCalldata
        );
        
        parameters[0] = seaportParameters;
        
        bytes memory x2y2Calldata = abi.encodeWithSelector(x2y2.failPurchase.selector);
        NFTMarketplaceRouter.PurchaseParameters memory x2y2Parameters = NFTMarketplaceRouter.PurchaseParameters(
            5 ether,
            NFTMarketplaceRouter.Marketplace.X2Y2,
            50,
            address(token),
            x2y2Calldata
        );
        
        parameters[1] = x2y2Parameters;

        bytes memory looksRareCalldata = abi.encodeWithSelector(looksRare.failPurchase.selector);
        NFTMarketplaceRouter.PurchaseParameters memory looksRareParameters = NFTMarketplaceRouter.PurchaseParameters(
            5 ether,
            NFTMarketplaceRouter.Marketplace.LooksRare,
            75,
            address(token),
            looksRareCalldata
        );
        
        parameters[2] = looksRareParameters;
        
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(NFTMarketplaceRouter.NoFillableOrders.selector));
        router.purchase{value: 15 ether}(NFTMarketplaceRouter.OrderType.BOTH, parameters);
        
        assertEq(alice.balance, 100 ether);
    }

    function testEmptyOrder() public {
        NFTMarketplaceRouter.PurchaseParameters[] memory parameters = new NFTMarketplaceRouter.PurchaseParameters[](1);

        bytes memory seaportCalldata = abi.encodeWithSelector(seaport.failPurchase.selector);
        NFTMarketplaceRouter.PurchaseParameters memory seaportParameters = NFTMarketplaceRouter.PurchaseParameters(
            5 ether,
            NFTMarketplaceRouter.Marketplace.LooksRare,
            0,
            address(token),
            seaportCalldata
        );
        
        parameters[0] = seaportParameters;
        
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(NFTMarketplaceRouter.NoFillableOrders.selector));
        router.purchase{value: 15 ether}(NFTMarketplaceRouter.OrderType.EMPTY, parameters);
        
        assertEq(alice.balance, 100 ether);
    }

    function testEmptyOrderArray() public {
        NFTMarketplaceRouter.PurchaseParameters[] memory parameters = new NFTMarketplaceRouter.PurchaseParameters[](0);
        
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(NFTMarketplaceRouter.NoOrders.selector));
        router.purchase{value: 15 ether}(NFTMarketplaceRouter.OrderType.EMPTY, parameters);
        
        assertEq(alice.balance, 100 ether);
    }
}

