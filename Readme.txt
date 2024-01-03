=======================================================
 Author: Lordmatics
 Date: 03/01/2024
 Description: Addon to visualise various Currencies
				Mitigating the tediousness of having to find them
=======================================================

- Load the addon via //lua l currencywatcher
- Position the bar as appropriate
- Optionally add the loading command to your init.txt file to have it loaded automatically when you login :)

Welcome to CurrencyWatcher Help Info,
 Simply drag the bar to where you want the info displayed,
  Useful Commands,
   //cw show - Makes the bar visible,
   //cw hide - Makes the bar invisible,
   //cw refresh - Forces a UI Update,
   //cw toggledebug - Will output packet info to help identify if all cases are accounted for. Bottom Left goes red in debug mode.,
   //cw help - Brings this menu back.,
   

What does the addon do?
- It emulates openning the currency menu by injecting 2 specific packets.
- From that result, the data associated with those menus will be correct
- I simply grab the data for the relevant fields I want, and store them on some UI.
- This means you can see at a glance relevant currency information without having to dive into a million menus.
- The addon will attempt to keep the UI as up to date as possible, I am doing this by listening for specific game packets
- Then responding to them with by injecting the currency menu packets and refreshing the UI.
	