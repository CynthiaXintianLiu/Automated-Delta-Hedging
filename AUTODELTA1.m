% ord=IBMatlab('action','sell', 'exchange','CBOE', 'quantity',3,...
% 'SecType','OPT', 'type','LMT', 'limitPrice',33, ...
% 'symbol','GME','expiry',20211231, 'right',{'Call','Put'}, ...
% 'strike',[160,160], 'ComboActions',{'Sell','Sell'})
portfolioData = IBMatlab('action','portfolio','type','positions');
%Cock_data=IBMatlab('action','portfolio','type','KO')
%%
orderID=IBMatlab('action','BUY','symbol','GOOG','')
delta=[];
positions=[];
pc=[];
symbols=[];
strikes=[];
maturities=[];
mids=[];

%% 
for i=1:length(portfolioData)
    if portfolioData(i).strike>0
        symbols=[symbols; portfolioData(i).symbol];
        positions=[positions; portfolioData(i).position];
        pc=[pc; portfolioData(i).right];
        strikes=[strikes; portfolioData(i).strike];
        maturities=[maturities; portfolioData(i).expiry];
        Q=IBMatlab('action','query', 'symbol',portfolioData(i).symbol, ...
          'secType','OPT','expiry',portfolioData(i).expiry, ...
          'multiplier',100, 'strike',portfolioData(i).strike,...
          'right',portfolioData(i).right);
      
        if isfield(Q,'delayed_bidPrice'); % the data are delayed
            Q.bidPrice=Q.delayed_bidPrice;
            Q.askPrice=Q.delayed_askPrice;
            Q.lastPrice=Q.delayed_lastPrice;
        end
        if Q.bidPrice>0 & Q.askPrice>0;        
           mids=[mids; (Q.bidPrice+Q.askPrice)/2];
        else
            disp('stop here')
        end
    end
end

%% 
% I now compute the deltas for my existing positions
r=0.04; q=0;
sigmas=[]; deltas=[]; gammas=[]; vegas=[];
for i=1:length(positions)
    Q=IBMatlab('action','query', 'symbol',symbols(i,:)); 
    % get quotes for the underlying
    ttm=(datenum(maturities(i,:),'yyyymmdd')-today)/365;
[sigma,delta,vega,convFlag]=impVol(Q.lastPrice,strikes(i),r,q,ttm,mids(i),pc(i)) ;
    sigmas=[sigmas; sigma];
    deltas=[deltas; delta];
    vegas=[vegas; vega];
    
end
% compute aggregate posiitons
% this only works when you have multiple positions in a single issue!!!
%%
symbol=symbols(1,:); % SPY

totalDelta=100*positions'*deltas; % aggregate delta
wantToHold=-totalDelta;
% Next, find the existing position of SPY shares
position=0; % initialize in case you have zero SPY shares
for i=1:length(portfolioData)
    if strcmp(portfolioData(i).localSymbol,symbol)
        position=portfolioData(i).position;
    end    
end
% Update quote data 
Q=IBMatlab('action','query', 'symbol',symbols(1,:));  
% again only works with single underlying
tradeNshares=round(wantToHold-position);
if tradeNshares<0;
    orderId = IBMatlab('action','SELL','symbol',symbol,'quantity',...
        -tradeNshares,'type','LMT','OutsideRTH',1,'limitPrice',Q.bidPrice-0.01);
elseif tradeNshares>0;
    orderId = IBMatlab('action','BUY','symbol',symbol,'quantity',...
        tradeNshares,'type','LMT','OutsideRTH',1,'limitPrice',Q.askPrice+0.01);
end

