pragma solidity ^0.4.17;

contract EcommerceStore{
    enum ProductStatus{OPEN,SOLD,UNSOLD}
    enum ProductCondition{NEW,USED}
    
    uint public productIndex;
    //the mapping from product id to shoppers address
    mapping(uint => address) productIdInstore; 
    
    //the mapping from shoppers to all of his products , and these products are stored in a mapping,we can find product by product id in this mapping
    mapping(address => mapping(uint => Product)) stores;
    
    struct Product{
        uint id;
        string name;
        string category;
        string imageLink;
        string descLink;
        uint auctionStartTime;
        uint auctionEndTime;
        uint startPrice;
        address highestBidder;
        uint highestBid;
        uint secondHighestBid;
        uint totalBids;
        ProductStatus status;
        ProductCondition condition;
        
        //bytes32 is the hash string of bidders's bid,one can bid a product more than one time
        //so his bid results to a product are stored in an mapping
        mapping (address => mapping(bytes32=>Bid)) bids;
    }
    
    //bid info
    struct Bid{
        address bidder;
        uint productId;
        uint value; //the amounts of eth sent by bidder when he bid
        bool revealed;
    }
    
    constructor() public{
        productIndex = 0;
    }
    
    function addProductToStore(string _name,string _category,string _imageLink,string _descLink,uint _auctionStartTime,
                              uint _auctionEndTime,uint _startPrice,uint _productCondition) public{
        
        require(_auctionStartTime < _auctionEndTime,"auctionStartTime should earlier than auctionEndTime");
        productIndex+=1;
        Product memory product = Product(productIndex,_name,_category,_imageLink,_descLink,_auctionStartTime,_auctionEndTime,
        _startPrice,0,0,0,0,ProductStatus.OPEN,ProductCondition(_productCondition));
        stores[msg.sender][productIndex] = product;
        productIdInstore[productIndex] = msg.sender;
    }
    
    function getProduct(uint _productId) public view returns(uint,string,string,string,string,uint,uint,uint,ProductStatus,ProductCondition){
        Product memory product = stores[productIdInstore[_productId]][_productId];
        return (product.id,product.name,product.category,product.imageLink,product.descLink,product.auctionStartTime,product.auctionEndTime,
        product.startPrice,product.status,product.condition);
    }
    
    function bid(uint _productId,bytes32 _bid) public payable returns(bool){
        Product storage product = stores[productIdInstore[_productId]][_productId];
        require(now >= product.auctionStartTime,"current time should be later than auction start time!");
        require(now <= product.auctionEndTime,"current time should be earlier than auction end time!");
        require(msg.value > product.startPrice,"bid price should higher than auction start price!");
        require(product.bids[msg.sender][_bid].bidder == 0,"repeated bid!");
        product.bids[msg.sender][_bid] = Bid(msg.sender,_productId,msg.value,false);
        product.totalBids+=1;
        return true;
    }
    
    function revealBid(uint _productId,string _amount,string _secret)public{
        Product storage product = stores[productIdInstore[_productId]][_productId];
        require(now >= product.auctionEndTime);
        bytes32 encryptedBid = sha3(_amount,_secret);
        Bid memory bidInfo = product.bids[msg.sender][encryptedBid];
        require(bidInfo.bidder>0,"bidder doesn't exist!");
        require(bidInfo.revealed==false,"bid has already been revealed");
        
        uint refund;
        uint amount = stringToUint(_amount);
        if(bidInfo.value < amount){//if amount of eth send by bidder is smaller than bid price that he gave,this is an illegal bid,give back all his money
            refund = bidInfo.value;
        }else{
            if(address(product.highestBidder)==0){//first time bid
                product.highestBidder = msg.sender;
                product.highestBid = amount;
                product.secondHighestBid = product.startPrice;
                refund = bidInfo.value - amount;//money left  after deduct amount of his bid price
            }else{//Someone has already bid
                if(amount > product.highestBid){//substitute highestBid
                    product.secondHighestBid = product.highestBid;
                    product.highestBidder.transfer(product.highestBid);//must return previous highest bidder's money first,this order cannot be changed
                    product.highestBid = amount;
                    product.highestBidder = msg.sender;
                    refund = bidInfo.value - amount;
                }else if(amount > product.secondHighestBid){
                    product.secondHighestBid = amount;
                    refund = bidInfo.value;
                }else{
                    refund = bidInfo.value;
                }
            }
        }
        
        product.bids[msg.sender][encryptedBid].revealed = true;//return money left after bid
        if(refund > 0){
            msg.sender.transfer(refund);
        }
        
    }
    
    
    function stringToUint(string s)  private pure  returns(uint){
        bytes memory b = bytes(s);
        uint result = 0;
        for(uint i = 0;i<b.length;i++){
            if(b[i] >= 48 && b[i] <= 57){
                result = result * 10 + (uint(b[i]) - 48);
            }
        }
        return result;
    }
    
    function highestBidderInfo(uint _productId)public view returns(address,uint,uint){
        Product memory product = stores[productIdInstore[_productId]][_productId];
        return (product.highestBidder,product.highestBid,product.secondHighestBid);
    }
    
    function totalBids(uint _productId) public view returns(uint){
        Product memory product = stores[productIdInstore[_productId]][_productId];
        return product.totalBids;
    }
}
