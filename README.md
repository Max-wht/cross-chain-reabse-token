# Cross-Chain-rebase-Token

1. A protocal that allow user to deposit into a vault and in return, receiver rebase token that represent underlying balance
2. rebase token -> `balanceOf` view function is dynamic to show the changing balance with time
   - Balance increase linearly with time
   - mint tokens when user do an action (minting, burning, transferring). so the protocal has to check whether the user's balance increase
3. interest rate
   - Individually set an interest rate or each user based on some global interest rate of the protocal at the time the user deposit into the vault
   - This global interest rate can only decrease to reward early adopters.
   - Increase token adoption
