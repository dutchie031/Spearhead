# Spearhead


## Contributing. 

- Make a fitting branch.
- Change reference in the file ./dev_classes.lua
- Add a "do script" trigger in the mission. 
  The script should be `assert(loadfile('<path to ./dev folder>' .. "dev_classes.lua"))()` 
  This will load all the class files and run the config and main.lua. 
  
  This way you can just hit "fly again" after making mission changes which speeds up development quite a lot.
