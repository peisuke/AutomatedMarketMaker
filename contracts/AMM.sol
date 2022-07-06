// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import './Math.sol';
import './FakeJPYC.sol';
import './MyToken.sol';

contract AMM {
    using SafeMath for uint;
   
    uint totalSupply;
    mapping(address => uint) public balanceOf;

    address public token1;
    address public token2;

    uint kLast;
    uint public constant MINIMUM_LIQUIDITY = 10**3;

    uint private unlocked = 1;

    event Mint(address indexed sender, uint amount1, uint amount2);
    event Burn(address indexed sender, uint amount0, uint amount1, address indexed to);
    event Swap(
        address indexed sender,
        address tokenIn,
        address tokenOut,
        uint amountIn,
        uint amountOut,
        address indexed to
    );

    constructor(address _token1, address _token2) {
        token1 = _token1;
        token2 = _token2;
    }

    modifier lock() {
        require(unlocked == 1, 'Locked.');
        unlocked = 0;
        _;
        unlocked = 1;
    }

    function _quote(uint amountA, uint reserveA, uint reserveB) internal pure returns (uint amountB) {
        require(amountA > 0, 'Insufficient amount.');
        require(reserveA > 0 && reserveB > 0, 'Insufficient liquidity.');

        //  K = amountA * amountB = reserveA * reserveB
        amountB = amountA.mul(reserveB) / reserveA;
    }

    //  流動性の追加後にKがキープされるよう、投入トークン量を計算
    function _computeLiquidityAmount(
        uint amount1Desired,
        uint amount2Desired
    ) internal view returns (uint amount1, uint amount2) {
        uint reserve1 = ERC20(token1).balanceOf(address(this));
        uint reserve2 = ERC20(token2).balanceOf(address(this));

        if (reserve1 == 0 && reserve2 == 0) {
            (amount1, amount2) = (amount1Desired, amount2Desired);
        } else {
            uint amount2Optimal = _quote(amount1Desired, reserve1, reserve2);
            if (amount2Optimal <= amount2Desired) {
                (amount1, amount2) = (amount1Desired, amount2Optimal);
            } else {
                uint amount1Optimal = _quote(amount2Desired, reserve2, reserve1);
                assert(amount1Optimal <= amount1Desired);
                (amount1, amount2) = (amount1Optimal, amount2Desired);
            }
        }
    }

    function _computeLiquidityProvide(
        uint _totalSupply,
        uint amount1,
        uint amount2,
        uint reserve1,
        uint reserve2
    ) internal pure returns (uint liquidity) {
        if(_totalSupply == 0) {
            // Genesis liquidity is issued 100 Shares
            uint _K = amount1.mul(amount2);
            liquidity = Math.sqrt(_K).sub(MINIMUM_LIQUIDITY);
        } else{
            //  suply * sqrt(a1 * a2 / r1 * r2)
            liquidity = Math.min(amount1.mul(_totalSupply) / reserve1, amount2.mul(_totalSupply) / reserve2);
        }
    }

    function _computeLiquidityWithdraw(
        uint _totalSupply,
        uint liquidity,
        uint reserve1,
        uint reserve2
    ) internal pure returns (uint amount1, uint amount2) {
        require(_totalSupply > 0, "TotalSupply cannot be zero.");
        amount1 = liquidity.mul(reserve1) / _totalSupply;
        amount2 = liquidity.mul(reserve2) / _totalSupply;
    }

    function _getTokenBalance(
        address _tokenIn,
        address _tokenOut
    ) internal view returns (uint balanceIn, uint balanceOut) {
        require(_tokenIn == token1 || _tokenOut == token1, 'FirstToken is required.');
        require(_tokenIn == token2 || _tokenOut == token2, 'SecondToken is required.');

        ERC20 tokenInContract = ERC20(_tokenIn);
        ERC20 tokenOutContract = ERC20(_tokenOut);
        balanceIn = tokenInContract.balanceOf(address(this));
        balanceOut = tokenOutContract.balanceOf(address(this));
    }

    function _getAmountOut(
        uint amountIn, 
        uint reserveIn, 
        uint reserveOut
    ) internal pure returns (uint amountOut) {
        require(amountIn > 0, 'Amount must not be zero.');
        require(reserveIn > 0 && reserveOut > 0, 'Insufficient liquidity.');

        uint numerator = amountIn.mul(reserveOut);
        uint denominator = reserveIn.add(amountIn);
        amountOut = numerator / denominator;
    }

    function _getAmountIn(
        uint amountOut, 
        uint reserveIn, 
        uint reserveOut
    ) internal pure returns (uint amountIn) {
        require(amountOut > 0, 'Amount must not be zero.');
        require(reserveIn > 0 && reserveOut > 0, 'Insufficient liquidity.');

        uint numerator = amountOut.mul(reserveIn);
        uint denominator = reserveOut.sub(amountOut);
        amountIn = numerator / denominator;
    }

    function _mint(address to, uint value) internal {
        totalSupply = totalSupply.add(value);
        balanceOf[to] = balanceOf[to].add(value);
    }

    function _burn(address to, uint value) internal {
        totalSupply = totalSupply.sub(value);
        balanceOf[to] = balanceOf[to].sub(value);
    }

    function provide(
        uint amount1Desired, 
        uint amount2Desired,
        address to
    ) external lock returns (uint amount1, uint amount2, uint liquidity) {
        (amount1, amount2) = _computeLiquidityAmount(amount1Desired, amount2Desired);
        require(amount1 > 0, "Amount of token1 cannot be zero.");
        require(amount2 > 0, "Amount of token2 cannot be zero.");

        ////////////////////////////////////////////////////////////////////////
        // transfer from sender to AMM
        ERC20 token1Contract = ERC20(token1);
        ERC20 token2Contract = ERC20(token2);

        //  トークン送付許可の確認 
        uint allowance1 = token1Contract.allowance(to, address(this));
        require(allowance1 >= amount1, "Allowance of token1 is not enough.");
        
        uint allowance2 = token2Contract.allowance(to, address(this));
        require(allowance2 >= amount2, "Allowance of token2 is not enough.");

        // トークンを送る前のAMMの保有トークン量をバックアップ
        uint reserve1 = ERC20(token1).balanceOf(address(this));
        uint reserve2 = ERC20(token2).balanceOf(address(this));

        //  トークン送信前にオーバーフローチェック
        uint totalToken1 = reserve1 + amount1;
        uint totalToken2 = reserve2 + amount2;
        require(totalToken1 <= type(uint112).max && totalToken2 <= type(uint112).max, 'Overflow token in the pool');

        ////////////////////////////////////////////////////////////////////////
        // Logic from UniswapV2, 流動性トークンのミント量を計算
        uint _totalSupply = totalSupply;
        if (_totalSupply == 0) {
            _mint(address(0), MINIMUM_LIQUIDITY);
        }

        liquidity = _computeLiquidityProvide(_totalSupply, amount1, amount2, reserve1, reserve2);
        require(liquidity > 0, 'Insufficient liquidity minted.');
        
        //  トークンをプールに送り、流動性トークンをミント
        token1Contract.transferFrom(to, address(this), amount1);
        token2Contract.transferFrom(to, address(this), amount2);
        _mint(to, liquidity);

        //  Kの計算 (token1 * token2)
        kLast = totalToken1.mul(totalToken2);

        emit Mint(msg.sender, amount1, amount2);
    }

    function withdraw(
        uint liquidity,
        address to
    ) external lock returns(uint amount1, uint256 amount2) {
        require(liquidity <= balanceOf[to], 'Not enough liquidity token in the pool.');
        ERC20 token1Contract = ERC20(token1);
        ERC20 token2Contract = ERC20(token2);

        uint balance1 = token1Contract.balanceOf(address(this));
        uint balance2 = token2Contract.balanceOf(address(this));

        //  返却されるトークン量
        uint _totalSupply = totalSupply;
        (amount1, amount2) = _computeLiquidityWithdraw(_totalSupply, liquidity, balance1, balance2);

        require(amount1 > 0 && amount2 > 0, 'Amount must not be zero.');
        require(balance1 >= amount1 && balance2 >= amount2, 'Token is not enough in the pool.');

        //  返却後のトークン量
        uint totalToken1 = balance1 - amount1;
        uint totalToken2 = balance2 - amount2;
        require(totalToken1 <= type(uint112).max && totalToken2 <= type(uint112).max, 'Overflow token in the pool.');

        //  liquidityを焼却し、トークンを返却する
        _burn(to, liquidity);
        token1Contract.transfer(to, amount1);
        token2Contract.transfer(to, amount2);

        //  Kの計算 (token1 * token2)
        kLast = totalToken1.mul(totalToken2);

        emit Burn(msg.sender, amount1, amount2, to);
    }

    // Returns the amount of Token2 that the user will get when swapping a given amount of Token1 for Token2
    function swap (
        address _tokenIn,
        address _tokenOut,
        uint _amountIn,
        address to
    ) external lock returns(uint _amountOut) {
        require(_tokenIn == token1 || _tokenOut == token1, 'FirstToken is required.');
        require(_tokenIn == token2 || _tokenOut == token2, 'SecondToken is required.');

        ERC20 tokenInContract = ERC20(_tokenIn);
        ERC20 tokenOutContract = ERC20(_tokenOut);
        uint balanceIn = tokenInContract.balanceOf(address(this));
        uint balanceOut = tokenOutContract.balanceOf(address(this));

        uint allowanceIn = tokenInContract.allowance(to, address(this));
        require(allowanceIn >= _amountIn, "Check the token allowance.");

        _amountOut = _getAmountOut(_amountIn, balanceIn, balanceOut);
        require(balanceOut >= _amountOut , 'Amount is not enough in AMM.');

        uint totalToken1 = balanceIn + _amountIn;
        uint totalToken2 = balanceOut - _amountOut;
        require(totalToken1 <= type(uint112).max && totalToken2 <= type(uint112).max, 'Overflow token in the pool.');

        tokenInContract.transferFrom(to, address(this), _amountIn);
        tokenOutContract.transfer(to, _amountOut);

        emit Swap(msg.sender, _tokenIn, _tokenOut, _amountIn, _amountOut, to);
    }

    function getTotalSupply() external view returns(uint amount) {
         amount = totalSupply;
    }

    function getShareOf(address addr) external view returns(uint amount) {
         amount = balanceOf[addr];
    }

    function computeLiquidityAmount(
        uint amount1Desired,
        uint amount2Desired
    ) public view returns (uint amount1, uint amount2) {
        (amount1, amount2) = _computeLiquidityAmount(amount1Desired, amount2Desired);
    }

    function computeLiquidityProvide(
        uint amount1,
        uint amount2
    ) public view returns (uint liquidity) {
        require(amount1 > 0, "Amount of token1 cannot be zero.");
        require(amount2 > 0, "Amount of token2 cannot be zero.");

        // トークンを送る前のAMMの保有トークン量をバックアップ
        uint reserve1 = ERC20(token1).balanceOf(address(this));
        uint reserve2 = ERC20(token2).balanceOf(address(this));

        uint _totalSupply = totalSupply;

        liquidity = _computeLiquidityProvide(
            _totalSupply,
            amount1,
            amount2,
            reserve1,
            reserve2
        );
    }

    function computeLiquidityWithdraw(
        uint liquidity
    ) public view returns (uint amount1, uint amount2) {
        require(liquidity > 0, "Liquidity cannot be zero.");
        uint _totalSupply = totalSupply;
        uint balance1 = ERC20(token1).balanceOf(address(this));
        uint balance2 = ERC20(token2).balanceOf(address(this));
        (amount1, amount2) = _computeLiquidityWithdraw(_totalSupply, liquidity, balance1, balance2);
    }

    function getLiquidityAmountOut(
        uint amountIn, 
        address _tokenIn,
        address _tokenOut
    ) public view returns (uint amountOut) {
        (uint balanceIn, uint balanceOut) = _getTokenBalance(_tokenIn, _tokenOut);
        amountOut = _quote(amountIn, balanceIn, balanceOut);
    }

    function getLiquidityAmountIn(
        uint amountOut, 
        address _tokenIn,
        address _tokenOut
    ) public view returns (uint amountIn) {
        (uint balanceIn, uint balanceOut) = _getTokenBalance(_tokenIn, _tokenOut);
        amountIn = _quote(amountOut, balanceOut, balanceIn);
    }

    function getAmountOut(
        uint amountIn, 
        address _tokenIn,
        address _tokenOut
    ) public view returns (uint amountOut) {
        (uint balanceIn, uint balanceOut) = _getTokenBalance(_tokenIn, _tokenOut);
        amountOut = _getAmountOut(amountIn, balanceIn, balanceOut);
    }

    function getAmountIn(
        uint amountOut, 
        address _tokenIn,
        address _tokenOut
    ) public view returns (uint amountIn) {
        (uint balanceIn, uint balanceOut) = _getTokenBalance(_tokenIn, _tokenOut);
        amountIn = _getAmountIn(amountOut, balanceIn, balanceOut);
    }
}
