--[[
    QuizBot v3 Module: Legacy Quiz Categories
    Ports the built-in category/topic bank from the v2 quizbot source.
    Registers: /categories, /category, /start, /topic
]]
local ctx = ...

local categories = {}
local categoryOrder = {}
local categoryManager = {}
categoryManager.__index = categoryManager

local function normalizeDifficulty(difficulty)
    difficulty = difficulty or ""
    return string.lower(tostring(difficulty))
end

local function makeQuestion(questionText, options, value)
    return {
        q = questionText,
        o = options,
        value = value or 1,
    }
end

function categoryManager.New(categoryName, difficulty)
    difficulty = normalizeDifficulty(difficulty)
    if not categories[categoryName] then
        categories[categoryName] = { name = categoryName, difficulties = {}, all = {} }
        table.insert(categoryOrder, categoryName)
    end
    local bucket = categories[categoryName].difficulties[difficulty]
    if not bucket then
        bucket = {}
        categories[categoryName].difficulties[difficulty] = bucket
    end
    local quiz = setmetatable({ categoryName = categoryName, difficulty = difficulty }, categoryManager)
    table.insert(bucket, quiz)
    return quiz
end

function categoryManager:Add(questionText, options, value)
    local q = makeQuestion(questionText, options, value)
    table.insert(self, q)
    table.insert(categories[self.categoryName].all, q)
end
do

local countriesEasy = categoryManager.New("Guess the country", "easy")
countriesEasy:Add("What country is this? 🇹🇷", {"Turkey", "Spain", "Greece", "Cyprus"})
countriesEasy:Add("What country is this? 🇪🇸", {"Spain", "Portugal", "Greece", "Mexico"})
countriesEasy:Add("What country is this? 🇵🇱", {"Poland", "Indonesia", "Austria", "Greenland"})
countriesEasy:Add("What country is this? 🇮🇳", {"India", "Pakistan", "Sri Lanka", "Afghanistan"})
countriesEasy:Add("What country is this? 🇳🇴", {"Norway", "Sweden", "Denmark", "Iceland"}, 2)

local countriesEasy2 = categoryManager.New("Guess the country", "easy")
countriesEasy2:Add("What country is this? 🇫🇷", {"France", "England", "Netherlands", "Russia"})
countriesEasy2:Add("What country is this? 🇬🇷", {"Greece", "Serbia", "Argentina", "Spain"})
countriesEasy2:Add("What country is this? 🇦🇷", {"Argentina", "Honduras", "Estonia", "Brazil"})
countriesEasy2:Add("What country is this? 🇻🇳", {"Vietnam", "China", "Japan", "Bejing"})
countriesEasy2:Add("What country is this? 🇷🇸", {"Serbia", "Bosnia", "Croatia", "Slovakia"}, 2)

local countriesMedium = categoryManager.New("Guess the country", "medium")
countriesMedium:Add("What country is this? 🇲🇽", {"Mexico", "Netherlands", "Iran", "Spain"})
countriesMedium:Add("What country is this? 🇵🇹", {"Portugal", "Brazil", "Madrid", "Spain"})
countriesMedium:Add("What country is this? 🇲🇦", {"Morocco", "Vietnam", "China", "Israel"}, 2)
countriesMedium:Add("What country is this? 🇧🇪", {"Belgium", "Germany", "France", "Romania"})
countriesMedium:Add("What country is this? 🇮🇩", {"Indonesia", "Poland", "Peru", "Switzerland"})

local countriesHard = categoryManager.New("Guess the country", "hard")
countriesHard:Add("What country is this? 🇸🇮", {"Slovenia", "Slovakia", "Russia", "Serbia"})
countriesHard:Add("What country is this? 🇪🇷", {"Eritrea", "Ecuador", "El Salvador"})
countriesHard:Add("What country is this? 🇫🇮", {"Finland", "Sweden", "Falkland Islands"})
countriesHard:Add("What country is this? 🇿🇲", {"Zambia", "Zimbabwe", "Zaire"}, 2)
countriesHard:Add("What country is this? 🇸🇴", {"Somalia", "Solomon Islands", "Samoa"})

local science = categoryManager.New("Science", "medium")
science:Add("The standard unit of measurement used for measuring force is which of the following?", {"Newton", "Mile", "Watt", "Kilogram"})
science:Add("How long does it take the earth to do one full rotation of the sun?", {"365 days", "7 days", "30 days"})
science:Add("Oil, natural gas and coal are examples of …", {"Fossil fuels", "Renewable resources", "Biofuels", "Geothermal resources"}, 2)
science:Add("Why do our pupils constrict in bright light?", {"To let in less light", "To give our eyes more oxygen", "To change our vision to 3D"})
science:Add("What is cooling lava called?", {"Igneous rocks", "Magma", "Fossils"})

local science2 = categoryManager.New("Science", "medium")
science2:Add("What is faster, sound or light?", {"Light", "Sound", "They travel at the same speed", "They don't move"})
science2:Add("Which of these is NOT one of Newton's laws of motion?", {"Objects at rest stay in motion", "Force equals mass times acceleration", "Every action has an equal and opposite reaction", "An object in motion stays in motion"})
science2:Add("Who developed the theory of relativity?", {"Einstein", "Newton", "Galileo", "Darwin"})
science2:Add("Which of these is not a state of matter?", {"Energy", "Solid", "Liquid", "Gas"})
science2:Add("What is the powerhouse of the cell?", {"Mitochondria", "Nucleus", "Cytoplasm", "Nucleic membrane"}, 2)

local history = categoryManager.New("History", "medium")
history:Add("Which of these countries did the Soviet Union NEVER invade?", {"Sweden", "Afghanistan", "Finland", "Poland"})
history:Add("What was the main cause of the French Revolution in 1789?", {"The social and economic inequality of the Third Estate", "The invasion of Napoleon Bonaparte", "Disputes over territorial boundaries with neighboring countries", "The spread of the Black Death"})
history:Add("What ancient civilization built the Machu Picchu complex?", {"Inca", "Aztec", "Maya", "Egypt"})
history:Add("What do people call the era before written records?", {"Prehistory", "Medieval Times", "Renaissance", "Industrial Age"})
history:Add("Which of these historical events happened first?", {"The American Revolution", "The French Revolution", "The Industrial Revolution", "The Russian Revolution"}, 2)

local history2 = categoryManager.New("History", "medium")
history2:Add("The disease that killed a third of Europe's population in the 14th century is known as:", {"Plague (Black Death)", "Spanish Flu", "Smallpox", "Malaria"})
history2:Add("Who discovered America in 1492?", {"Christopher Columbus", "Marco Polo", "Ferdinand Magellan", "Leif Erikson"})
history2:Add("Which country gifted the Statue of Liberty to the United States?", {"France", "Germany", "United Kingdom", "Spain"})
history2:Add("What was the name of the period of renewed interest in art and learning?", {"Renaissance", "Reformation", "Enlightenment", "Industrial Revolution"}, 2)
history2:Add("Which famous trade route connected Europe and Asia?", {"Silk Road", "Spice Route", "Amber Road", "Trans-Saharan Route"})

local foodAndDrink = categoryManager.New("Food and Drink", "medium")
foodAndDrink:Add("Which country is the largest producer of coffee in the world?", {"Brazil", "Vietnam", "Colombia", "Ethiopia"})
foodAndDrink:Add("What is the name of the Italian dessert made from layers of sponge cake soaked in coffee and mascarpone cheese?", {"Tiramisu", "Maritozzo", "Cannoli", "Zabaglione"})
foodAndDrink:Add("What is the national dish of England?", {"Fish and Chips", "Shepherd's Pie", "Yorkshire Pudding", "Sunday Roast"})
foodAndDrink:Add("What is the name of the fermented milk drink that is popular in Central Asia & Eastern Europe?", {"Kefir", "Karin", "Kulmel", "Yogurt"})
foodAndDrink:Add("Which country does feta cheese come from?", {"Greece", "Switzerland", "Spain", "France"}, 2)

local trivia = categoryManager.New("Trivia", "medium")
trivia:Add("Which is NOT a Nobel Prize category?", {"Mathematics", "Physics", "Literature", "Chemistry"})
trivia:Add("Which musical instrument has 47 strings and seven pedals?", {"Harp", "Piano", "Guitar", "Violin"})
trivia:Add("What is the capital city of Japan?", {"Tokyo", "Beijing", "Seoul", "Bangkok"})
trivia:Add("Which country is the only one to have a non-rectangular flag?", {"Nepal", "Switzerland", "Japan", "Qatar"})
trivia:Add("'Bokmål' and 'Nynorsk' are the two official written forms of which language?", {"Norwegian", "Italian", "Danish", "Spanish"}, 2)

local trivia2 = categoryManager.New("Trivia", "medium")
trivia2:Add("Which animal is the national emblem of Australia?", {"Kangaroo", "Koala", "Emu", "Platypus"})
trivia2:Add("What does the Richter scale measure?", {"Earthquake intensity", "Wind Speed", "Temperature", "Tornado Strength"}, 2)
trivia2:Add("Which currency is used in Japan?", {"Yen", "Dollar", "Euro", "Pound"})
trivia2:Add("What is the hardest natural substance on Earth?", {"Diamond", "Gold", "Iron", "Platinum"})
trivia2:Add("In sport, what does the term PGA refer to?", {"Professional Golfers Association", "Par Golfing Average", "Playing Golf Average", "Part-Time Golfing Amaterurs"})

local guessTheLanguage = categoryManager.New("Guess the language", "medium")
guessTheLanguage:Add("Je suis désolé", {"French", "Spanish", "Italian", "Portuguese"})
guessTheLanguage:Add("בוקר טוב", {"Hebrew", "Tamil", "Lao", "Mandarin"})
guessTheLanguage:Add("Guten Tag", {"German", "Tagalog", "Finnish", "Dutch"})
guessTheLanguage:Add("こんにちは", {"Japanese", "Chinese", "Turkish", "Arabic"}, 2)
guessTheLanguage:Add("नमस्ते", {"Hindi", "Indonesian", "Cantonese", "Nahuatl"})

local capitals = categoryManager.New("Capital Cities", "easy")
capitals:Add("What is the capital city of the USA?", {"Washington D.C.", "New York City", "Los Angeles", "Austin"})
capitals:Add("What is the capital city of Finland?", {"Helsinki", "Stockholm", "Dublin", "Reykjavik"}, 2)
capitals:Add("What is the capital city of Poland?", {"Warsaw", "Kiev", "Moscow", "Krakow"})
capitals:Add("What is the capital city of Germany?", {"Berlin", "Frankfurt", "Hamburg", "Dusseldorf"})
capitals:Add("What is the capital city of Canada?", {"Ottawa", "Toronto", "Vancouver", "Montreal"})

local capitalsHard = categoryManager.New("Capital Cities", "hard")
capitalsHard:Add("What is the capital of Belgium?", {"Brussels", "Liege", "Amsterdam"})
capitalsHard:Add("What is the capital of Somalia?", {"Mogadishu", "Garoowe", "Berbera"})
capitalsHard:Add("What is the capital city of Mongolia?", {"Ulaanbaatar", "Hanoi", "Seoul"})
capitalsHard:Add("What is the capital city of Australia?", {"Canberra", "Sydney", "Perth"})
capitalsHard:Add("What is the capital city of New Zealand?", {"Wellington", "Auckland", "Hamilton"})

local geography = categoryManager.New("Geography", "easy")
geography:Add("On which continent is the Sahara Desert located?", {"Africa", "Asia", "Europe", "South America"})
geography:Add("Which river flows through London?", {"River Thames", "River Severn", "River Trent", "The Nile"})
geography:Add("Which of these cities is NOT a national capital?", {"Sydney", "Oslo", "Wellington", "Bangkok"}, 2)
geography:Add("Which continent has the largest land area?", {"Asia", "Africa", "Europe", "South America"})
geography:Add("What is the smallest country in the world?", {"Vatican City", "Belgium", "Luxembourg", "Hungary"})

local geographyMedium = categoryManager.New("Geography", "medium")
geographyMedium:Add("Which island is the largest in the world?", {"Greenland", "Madagascar", "Borneo", "New Guinea"})
geographyMedium:Add("Which continent has the most countries?", {"Africa", "Europe", "Asia", "Australia"})
geographyMedium:Add("Which one of the following countries is further north?", {"Scotland", "The Netherlands", "Belgium", "Poland"})
geographyMedium:Add("What is the longest river in the world?", {"The Nile", "Amzon River", "Yangtze River", "Yellow River"})
geographyMedium:Add("Which ocean is the deepest?", {"Pacific Ocean", "Atlantic Ocean", "Indian Ocean", "Arctic Ocean"}, 2)

local geographyHard = categoryManager.New("Geography", "hard")
geographyHard:Add("Which country has the longest coastline?", {"Canada", "Chile", "Norway", "Australia"})
geographyHard:Add("Which continent is the only one without a desert?", {"Europe", "Asia", "North America", "Africa"})
geographyHard:Add("Which one of the following countries is not an enclave?", {"Italy", "Vatican City", "San Marino", "Lasotho"}, 2)
geographyHard:Add("Which is the northernmost capital city in the world?", {"Reykjavik, Iceland", "Oslo, Norway", "Helsinki, Finland", "Moscow, Russia"})
geographyHard:Add("Which city is the only one located on two continents?", {"Istanbul", "Cairo", "Moscow", "Panama City"})

local gaming = categoryManager.New("Gaming", "medium")
gaming:Add("What is the best-selling video game of all time?", {"Minecraft", "FIFA 18", "Call of Duty: Modern Warfare 3", "Tetris"})
gaming:Add("What was the first commercially successful video game?", {"Pong", "Donkey Kong Country", "Super Mario Bros", "Spacewar"})
gaming:Add("What is the name of the main character in the Legend of Zelda series?", {"Link", "Zelda", "Ganon", "Mario"})
gaming:Add("What video game did Mario, the Nintendo character, first appear in?", {"Donkey Kong", "Super Mario Bros", "Marios Cement Factory", "Mario Bros"}, 2)
gaming:Add("What is the name of the latest virtual reality device developed by Valve?", {"Steam Frame", "Oculus Rift", "Meta Quest", "Valve VR"})

local gaming2 = categoryManager.New("Gaming", "medium")
gaming2:Add("Which company created the Mario franchise?", {"Nintendo", "Sony", "Microsoft", "Sega"})
gaming2:Add("What is the name of the game developer who created Half-Life, Portal, and Counter-Strike?", {"Valve", "Blizzard", "Bethesda", "Rockstar"})
gaming:Add("What is the name of the gaming console that was released by Nintendo in 2006 and featured motion controls?", {"Wii", "Switch", "GameCube", "DS"})
gaming2:Add("What is the name of the platform game series that features a plumber who rescues a princess from a turtle-like villain?", {"Super Mario", "Sonic the Hedgehog", "Crash Bandicoot", "Cuphead"})
gaming2:Add("How many standalone Grand Theft Auto titles have been released?", {"7", "5", "8", "10"}, 2)

local movies = categoryManager.New("Movies", "medium")
movies:Add("Which actor played the role of Jack Sparrow in the 'Pirates of the Caribbean' franchise?", {"Johnny Depp", "Orlando Bloom", "Keira Knightley", "Geoffrey Rush"})
movies:Add("What was the first movie in the Marvel Cinematic Universe?", {"Iron Man", "The Avengers", "Batman", "Spider-Man"}, 2)
movies:Add("Which movie is based on the novel by J.R.R. Tolkien?", {"The Lord of the Rings", "The Chronicles of Narnia", "The Hunger Games", "The Da Vinci Code"})
movies:Add("What is the name of the protagonist in The Matrix?", {"Neo", "Morpheus", "Trinity", "Cypher"})
movies:Add("In the movie 'Frozen', who is Olaf?", {"A snowman", "A ghost", "A knight", "A reindeer"})

local roblox = categoryManager.New("Roblox", "easy")
roblox:Add("What was the original name of Roblox?", {"DynaBlocks", "SuperBlocks", "XtraBlocks"})
roblox:Add("What is the name of Roblox's other virtual currency that has been removed since 2016?", {"Tix", "Builder Coins", "Ro-Points"})
roblox:Add("What program do you use to make games on Roblox?", {"Roblox Studio", "Roblox Player", "Roblox Create", "Roblox Creator"})
roblox:Add("Roblox's private servers were previously known as which of the following?", {"VIP servers", "Personal servers", "Exclusive servers"})
roblox:Add("Who won the RB Battles season 1 championship?", {"KreekCraft", "Tofuu", "Seedeng", "BriannaPlayz"}, 2)

local roblox2 = categoryManager.New("Roblox", "easy")
roblox2:Add("What is another name for the avatar shop?", {"Catalog", "Avatar Creator", "Avatar Editor"})
roblox2:Add("What programming language do you need to use to create Roblox games?", {"Luau", "JavaScript", "Python", "PHP"}, 2)
roblox2:Add("What is the name of Roblox's annual developer conference?", {"RDC", "Robloxcon", "Robloxx", "Blockfest"})
roblox2:Add("What was the former name of Roblox premium?", {"Builders Club", "Roblox Plus", "Roblox Pro", "VIP Club"})
roblox2:Add("What was the very first Roblox game to reach 1B+ visits?", {"MeepCity", "Arsenal", "Build a Boat For Treasure", "Adopt Me"}, 2)

local english = categoryManager.New("English", "easy")
english:Add("Which of the following is a proper noun?", {"London", "City", "River", "Mountain"})
english:Add("What is the correct way to punctuate this sentence?", {"However, I don't agree with your opinion.", "However I, don't agree with your opinion.", "However I don't, agree with your opinion.", "However; I don't agree with your opinion."})
english:Add("Which word is an adjective?", {"Beautiful", "Run", "Quickly", "Table"})
english:Add("Which is the correct spelling?", {"Necessary", "Neccessary", "Nessessary", "Necessay"})
english:Add("What is the subject in the sentence: 'The cat chased the mouse across the yard'?", {"The cat", "The mouse", "The yard", "Chased"}, 2)

local animals = categoryManager.New("Animals", "easy")
animals:Add("What is the largest land animal?", {"Elephant", "Giraffe", "Whale", "Rhino"})
animals:Add("What is the name of a baby kangaroo?", {"Joey", "Cub", "Pup", "Kit"})
animals:Add("Capable of exceeding 186 miles per hour, what is the fastest creature in the animal kingdom?", {"Peregrine falcon", "Cheetah", "Horse", "Lion"})
animals:Add("What is the only mammal that can fly?", {"Bat", "Penguin", "Pterodactyl", "Dragon"}, 2)
animals:Add("Which of these “fish” is actually a fish?", {"Swordfish", "Starfish", "Crayfish", "Jellyfish"})

local sports = categoryManager.New("Sports", "easy")
sports:Add("In which sport might you perform a 'bicycle kick'?", {"Football (Soccer)", "Basketball", "Rugby", "Tennis"})
sports:Add("Which country is famous for inventing sumo wrestling?", {"Japan", "China", "India", "Thailand"})
sports:Add("What animal is used in the traditional sport of polo?", {"Horse", "Camel", "Elephant", "Yak"})
sports:Add("What sport is also known as table tennis?", {"Ping Pong", "Badminton", "Squash", "Tennis"})
sports:Add("Which sport uses the terms 'strike' and 'spare'?", {"Bowling", "Baseball", "Cricket", "Golf"}, 2)

local minecraft = categoryManager.New("Minecraft", "easy")
minecraft:Add("What is the name of the green creature that explodes?", {"Creeper", "Zombie", "Skeleton", "Slime"})
minecraft:Add("Which tool is best for digging stone and bricks?", {"Pickaxe", "Shovel", "Axe", "Drill"})
minecraft:Add("What is the name of the dimension where you fight the Ender Dragon?", {"The End", "The Nether", "The Overworld", "The Void"}, 2)
minecraft:Add("What resource do you need to trade with villagers?", {"Emerald", "Apple", "Gold", "Iron"})
minecraft:Add("What block can you use to make a portal to the Nether?", {"Obsidian", "Netherrack", "Cobblestone", "Bedrock"})

local chess = categoryManager.New("Chess", "medium")
chess:Add("What is the name of the piece that can only move diagonally?", {"Bishop", "Knight", "Queen"})
chess:Add("What is the term for a situation where a king is under attack and cannot escape?", {"Checkmate", "Stalemate", "En passant", "Castling"})
chess:Add("What is the name of the chess strategy that involves sacrificing a piece to gain an advantage?", {"Gambit", "Fork", "Pin", "Skewer"})
chess:Add("What is the name of the special move where a king and a rook swap places?", {"Castling", "Promotion", "Capture", "Fork"})
chess:Add("Which piece is involved in 'en passant'?", {"Pawn", "Queen", "Bishop", "Knight"}, 2)

local WWII = categoryManager.New("WWII", "hard")
WWII:Add("Which countries formed the Axis powers in WWII?", {"Germany, Italy and Japan", "France, Britain and Russia", "China, India and Australia", "Canada, Mexico and Brazil"})
WWII:Add("Which country was attacked by Japan in 1941, prompting its entry into WWII?", {"USA", "China", "India", "Australia"})
WWII:Add("Which two countries were the first to declare war on Germany?", {"Britain and France", "Italy and Greece", "Norway and Denmark", "Poland and Russia"})
WWII:Add("What was the name of the operation that marked the Allied invasion of Normandy in 1944?", {"Operation Overlord", "Operation Barbarossa", "Operation Torch", "Operation Garden"}, 2)
WWII:Add("What was the name of the code-breaking machine developed by the British to crack German ciphers?", {"Bombe", "Turing", "Lorenz", "Enigma"})

local WWI = categoryManager.New("WWI", "hard")
WWI:Add("Which country made the first declaration of war in WWI?", {"Austria-Hungary", "Serbia", "Russia", "Germany"})
WWI:Add("What was the name of the British passenger ship that was sunk by a German submarine in 1915?", {"Lusitania", "Titanic", "Britannia", "Olympic"})
WWI:Add("What was the nickname given to the type of warfare that involved digging trenches and fighting from them?", {"Trench warfare", "Guerrilla warfare", "Dirt warfare", "Siege warfare"})
WWI:Add("What caused Great Britain to join World War I?", {"German troops marching through Belgium", "German bombing raids on London", "German use of illegal chemicals", "Germans sinking British civilian ships"})
WWI:Add("What was the name of the alliance between Germany, Austria-Hungary and Italy?", {"Triple Alliance", "The Axis Powers", "The Triple Entente", "The League of Nations"}, 2)

local luau = categoryManager.New("Luau", "hard")
luau:Add("What is the keyword for defining a function in Luau?", {"function", "def", "local", "sub"})
luau:Add("What is the syntax for creating a comment in Luau?", {"-- comment", "// comment", "# comment", "' comment"}, 2)
luau:Add("What is the data type for storing multiple values in Luau?", {"table", "array", "list", "set"})
luau:Add("How do you declare a table in Luau?", {"local table = {}", "local table = []", "local table = table.new()", "local table = ()"})
luau:Add("What is the symbol for concatenating strings in Luau?", {"..", "+", "&", "%"}, 2)

local astronomy = categoryManager.New("Astronomy", "medium")
astronomy:Add("What is the name of the dwarf planet that was once considered a ninth planet in our solar system?", {"Pluto", "Ceres", "Eris", "Haumea"})
astronomy:Add("What is the name of the theory that describes how the universe began with a massive expansion from a single point?", {"The Big Bang theory", "The Steady State theory", "The Inflationary theory", "The String theory"})
astronomy:Add("What is the name of the largest planet in our solar system?", {"Jupiter", "Saturn", "Earth", "Neptune"})
astronomy:Add("What is the term for a group of stars that form a recognizable pattern?", {"A constellation", "A nebula", "A cluster", "A galaxy"})
astronomy:Add("What is the name of the largest moon in our solar system?", {"Ganymede", "Titan", "Io", "Europa"}, 2)

local memes = categoryManager.New("Memes", "easy")
memes:Add("Which meme features a dog sitting in a burning room?", {"This is fine", "Doge", "Grumpy Cat", "Bad Luck Brian"})
memes:Add("What is the name of the frog character that is often associated with the phrase 'feels good man'?", {"Pepe", "Kermit", "Frogger", "Freddy"}, 2)
memes:Add("What is the term for a meme that looks low-quality and pixelated?", {"Deep fried", "Dank", "Cringe", "Ironic"})
memes:Add("Which animal is associated with the 'Doge' meme?", {"Shiba Inu", "Grumpy Cat", "Keyboard Cat", "Nyan Cat"})
memes:Add("What is the name of the meme featuring a man's head sticking out of a while toilet bowl?", {"Skibidi Toilet", "TF2 Guy", "Fanum Tax", "Smurf Cat"})

local anime = categoryManager.New("Anime", "easy")
anime:Add("What is the name of the main character in Naruto?", {"Naruto Uzumaki", "Naruto Uchiha", "Kakashi Naruto", "Itachi Uchiha"})
anime:Add("What is the name of the pirate crew that Monkey D. Luffy leads in One Piece?", {"Straw Hat Pirates", "Blackbeard Pirates", "Red Hair Pirates", "Whitebeard Pirates"})
anime:Add("What is the name of the powerful notebook that can kill anyone whose name is written in it in it?", {"Death Note", "Kira Note", "Shinigami Note", "Life Note"})
anime:Add("In Death Note, how does Light Yagami first discover the infamous notebook?", {"He sees it fall from the sky", "He receives it as a gift from a friend", "It is delivered to him in a mysterious box", "He finds it on the subway"}, 2)
anime:Add("What is the name of the main character in the Pokémon series?", {"Ash Ketchum", "Naruto Uzumaki", "Gary Oak", "Pikachu"})

local scienceHard = categoryManager.New("Science", "hard")
scienceHard:Add("What is the name of the largest bone in the human body?", {"Femur", "Humerus", "Tibia", "Pelvis"})
scienceHard:Add("Which of these particles is its own antiparticle?", {"Photon", "Proton", "Electron", "Neutron"})
scienceHard:Add("What is the name of the phenomenon in which light is scattered by particles in a medium that are not much larger than the wavelength of the light?", {"Rayleigh scattering", "Diffraction", "Refraction", "Dispersion"}, 2)
scienceHard:Add("What is the name of the branch of mathematics that deals with the properties and relationships of abstract entities such as numbers, symbols, sets, and functions?", {"Algebra", "Geometry", "Calculus", "Logic"})
scienceHard:Add("What is the name of the unit of electric potential difference, electric potential energy per unit charge?", {"Volt", "Ampere", "Ohm", "Watt"})

local mathCategory = categoryManager.New("Math", "easy")
mathCategory:Add("What is the value of PI (rounded to two decimal places)?", {"3.14", "3.15", "3.16", "3.17"})
mathCategory:Add("The property that states that a + b = b + a has what name?", {"Commutative property", "Associative property", "Distributive property", "Identity property"}, 2)
mathCategory:Add("What is the formula for the area of a circle?", {"pi * r^2", "2 * pi * r", "pi * d", "pi * r"})
mathCategory:Add("What is the name of the branch of mathematics that studies shapes and angles?", {"Geometry", "Algebra", "Calculus", "Arithmetic"})
mathCategory:Add("What is the value of x in the equation 2x + 5 = 13?", {"4", "3", "5", "6"})

local mathHard = categoryManager.New("Math", "hard")
mathHard:Add("What is the name of the theorem that states that a² + b² = c² for a right triangle?", {"Pythagorean theorem", "Fermat's last theorem", "Binomial theorem", "Euclid's theorem"})
mathHard:Add("What is the derivative of e^x?", {"e^x", "x*e^(x-1)", "ln(x)", "1/e^x"})
mathHard:Add("What is the name of the constant that is approximately equal to 2.71828?", {"Euler's number", "The golden ratio", "PI", "Planck's constant"})
mathHard:Add("What is the name of the sequence that starts with 1, 1, 2, 3, 5, 8, ...?", {"Fibonacci Sequence", "Arithmetic Sequence", "Geometric Sequence", "Harmonic Sequence"}, 2)
mathHard:Add("What is the name of the branch of mathematics that deals with patterns and sequences?", {"Combinatorics", "Algebra", "Calculus", "Geometry"})

local coldWar = categoryManager.New("Cold War", "hard")
coldWar:Add("In 1946 Winston Churchill popularized what term used to describe Soviet relations with Western powers?", {"Iron curtain", "Mutually assured destruction", "Quagmire", "Danger to society"})
coldWar:Add("Frequently cited as the counterpart to the CIA, what was the name of the Soviet intelligence agency?", {"KGB", "ICBM", "SALT", "DMZ"})
coldWar:Add("Devised in 1959, the DEFCON system has five stages of military readiness. Which DEFCON rating is used when a nuclear attack is imminent or already underway?", {"DEFCON 1", "DEFCON 3", "DEFCON 5"})
coldWar:Add("Although never fully leaving the organization, in 1966 what country withdrew its military from NATO and expelled NATO headquarters from its borders?", {"France", "United States", "Poland", "West Germany"})
coldWar:Add("Often seen as the Soviet version of the United States’ Vietnam quagmire, the U.S.S.R.’s 10-year-long invasion of what country began in 1979?", {"Afghanistan", "Poland", "Czechoslovakia", "Ukraine"}, 2)

local chemistry = categoryManager.New("Chemistry", "hard")
chemistry:Add("What is the chemical formula of water?", {"H2O", "CO2", "O2", "2HO"})
chemistry:Add("What is the name of the process that converts a solid into a gas without passing through a liquid state?", {"Sublimation", "Evaporation", "Condensation", "Deposition"})
chemistry:Add("What is the name of the element with the symbol K?", {"Potassium", "Calcium", "Krypton", "Kalium"})
chemistry:Add("What is the name of the process that separates a mixture of liquids based on their boiling points?", {"Distillation", "Filtration", "Crystallization", "Chromatography"})
chemistry:Add("What is the name of the organic compound that has the general formula CnH2n+2?", {"Alkane", "Alkene", "Alkyne", "Ammonia"}, 2)

local biology = categoryManager.New("Biology", "medium")
biology:Add("What is the name of the process by which plants make their own food?", {"Photosynthesis", "Respiration", "Transpiration", "Fermentation"})
biology:Add("What is the smallest unit of life?", {"Cell", "Atom", "Molecule", "Organ"})
biology:Add("What is the main function of red blood cells?", {"Oxygen transport", "Fighting infections", "Blood clotting", "Producing antibodies"})
biology:Add("What are the main building blocks of proteins?", {"Amino acids", "Fatty acids", "Nucleic acids", "Glucose"}, 2)
biology:Add("What is the name of the molecule that carries genetic information in most living organisms?", {"DNA", "Cell", "ATP", "ADP"})

local sayings = categoryManager.New("Sayings and Idioms", "easy")
sayings:Add("Which idiom means to reveal a secret?", {"Let the cat out of the bag", "Paint the town red", "Beat around the bush", "Bite the bullet"})
sayings:Add("What does 'a piece of cake' refer to?", {"Something very easy", "A dessert", "A difficult task", "A small portion"})
sayings:Add("Which idiom means to be in trouble?", {"In hot water", "On cloud nine", "Under the weather", "Out of the blue"})
sayings:Add("What does 'hold your horses' mean?", {"Be patient", "Ride horses", "Work hard", "Go faster"})
sayings:Add("What does 'break a leg' mean?", {"Good luck", "Actually break a leg", "Run away", "Take a break"}, 2)

local internetSlang = categoryManager.New("Internet Slang", "easy")
internetSlang:Add("What does 'LOL' stand for?", {"Laugh Out Loud", "Lots Of Love", "Living On Land", "Look Out Left"})
internetSlang:Add("What does 'FOMO' stand for?", {"Fear Of Missing Out", "Friends Of My Office", "Fond Of Moving On", "Full Of Many Options"})
internetSlang:Add("What does 'IMO' stand for?", {"In My Opinion", "Internet Mail Order", "It's Monday Obviously", "I Mean Okay"})
internetSlang:Add("What is the meaning of 'SMH'?", {"Shaking My Head", "So Much Hate", "Send More Help", "Smashing My Head"})
internetSlang:Add("What does 'IIRC' stand for?", {"If I Recall Correctly (If I Remember Correctly)", "It Is Really Cool (Is It Really Cool)", "I'm Incredibly Rich, Child", "Interesting Information Requires Consideration"}, 2)

local internetSlang2 = categoryManager.New("Internet Slang", "medium")
internetSlang2:Add("What does 'FTFY' mean?", {"Fixed That For You", "For The Following Year", "Forget That, Find Yourself", "Faster Than Fifty Yaks"})
internetSlang2:Add("What is the meaning of 'AMA'?", {"Ask Me Anything", "Always Making Assumptions", "Another Missed Appointment", "Awesome Meme Alert"})
internetSlang2:Add("What does 'YOLO' stand for?", {"You Only Live Once", "Your Own Life Obligations", "Yesterday's Old Leftover Onions", "Yelling Out Loud Often"})
internetSlang2:Add("What does 'OMW' stand for?", {"On My Way", "Oh My Word", "Only Men Welcome", "Official Meme Website"})
internetSlang2:Add("What is the meaning of 'ITT'?", {"In This Thread", "I'll Tell Them", "I Think That", "I Talked To"}, 2)

local guessTheMovie = categoryManager.New("Guess the Movie", "easy")
guessTheMovie:Add("Which movie features a young wizard attending the Hogwarts School?", {"Harry Potter and the Philosopher's Stone", "The Lord of the Rings", "The Chronicles of Narnia", "The Wizard of Oz"})
guessTheMovie:Add("What movie tells the story of a clownfish searching for his son across the ocean?", {"Finding Nemo", "Shark Tale", "The Little Mermaid", "Free Billy"})
guessTheMovie:Add("Which sci-fi film features blue-skinned aliens called the Na'vi?", {"Avatar", "Star Wars", "Alien", "District 9"})
guessTheMovie:Add("In what movie does Tom Hanks play a man stranded on an island with only a volleyball for company?", {"Cast Away", "The Terminal", "Forrest Gump", "Saving Private Ryan"}, 2)
guessTheMovie:Add("What movie tells the story of a group of toys that come to life when humans aren't around?", {"Toy Story", "The Lego Movie", "Small Soldiers", "Wreck-It Ralph"})

local guessTheBook = categoryManager.New("Guess the Book", "medium")
guessTheBook:Add("In which book does a young girl named Alice fall down a rabbit hole into a fantastical world?", {"Alice in Wonderland", "The Wonderful Wizard of Oz", "Peter Pan", "The Secret Garden"})
guessTheBook:Add("Which book tells the story of a character named Bilbo Baggins?", {"The Hobbit", "The Lord of the Rings", "The Silmarillion", "Eragon"})
guessTheBook:Add("Which book features a dystopian society where books are burned?", {"Fahrenheit 451", "Brave New World", "Lord of the Flies", "Slaughterhouse-Five"}, 2)
guessTheBook:Add("Which book tells the story of a boy named Charlie who wins a golden ticket?", {"Charlie and the Chocolate Factory", "Charlie and the Giant Peach", "Wonka's Chocolate Factory", "The BFG"})
guessTheBook:Add("Which book tells the story of a boy who never grows up and lives in Neverland?", {"Peter Pan", "The Wonderful Wizard of Oz", "Alice in Wonderland", "The Chronicles of Narnia"})

local music = categoryManager.New("Music", "medium")
music:Add("Which band released the album 'The Dark Side of the Moon'?", {"Pink Floyd", "The Beatles", "Led Zeppelin", "The Rolling Stones"})
music:Add("What do you call the words of a song?", {"Lyrics", "Melody", "Harmony", "Rhythm"})
music:Add("Which of these is not a wind instrument?", {"Violin", "Flute", "Clarinet", "Saxophone"})
music:Add("What is the national anthem of the United States called?", {"The Star Spangled Banner", "God Save the Queen", "La Marseillaise", "O Canada"})
music:Add("Which of these is not a type of guitar?", {"Cello", "Acoustic", "Electric", "Bass"}, 2)

local brainrot = categoryManager.New("Brainrot", "easy")
brainrot:Add("What's the word for those strange little men stuck in toilets?", {"Skibidi", "Toilet snakes", "Plumbing gnomes", "Bowl boys"})
brainrot:Add("What is it called when someone talks at lenght in an irritating manner?", {"Yapping", "Woofing", "Ranting", "Monologuing"})
brainrot:Add("Which term describes someone who's a bit of a lone wolf—perhaps even better than an alpha?", {"Sigma", "Omega", "Beta", "Zeta"})
brainrot:Add("In which U.S. state are wild, strange, unfortunate things most likely to happen, according to the internet?", {"Only in Ohio", "Only in Alaska", "Only in Florida", "Only in Mississippi"})
brainrot:Add("What is the name of the purple McDonad's drink?", {"Grimace Shake", "Sussy Punch", "Blueberry McFlurry", "Expired Shake"}, 2)

local brainrot2 = categoryManager.New("Brainrot", "easy")
brainrot2:Add("What does it mean to be 'cooked'?", {"In a really bad position", "Extremely hungry", "Feeling very tired", "Excited or thrilled"})
brainrot2:Add("Fill in the blank: 'Erm, what the ___'?", {"sigma", "dog", "heck", "alpha"})
brainrot2:Add("What is the term for excessively praising or complimenting someone?", {"Glazing", "Rizzing", "Gassing", "Fawning"})
brainrot2:Add("Who is the main enemy of Skibidi Toilet?", {"Cameraman", "Janitor", "Skibidi Sink", "G-Man"}, 2)
brainrot2:Add("Finish the quote: 'Just put the ___ in the bag.'", {"Fries", "Money", "Skibidi", "Rizz"})

local gamerWords = categoryManager.New("Gamer Words", "easy")
gamerWords:Add("What does 'GG' mean?", {"Good Game", "Get Good", "Great Goal", "Gamer Girl"})
gamerWords:Add("Which phrase tells players to take a real-world break and go outside?", {"Touch Grass", "Eat a Salad", "Get Off", "Chillax"})
gamerWords:Add("A 'Noob' is a:", {"New Player", "Night Ops Bot", "Cheater", "Nintendo Spectator"})
gamerWords:Add("'OP' stands for:", {"Overpowered", "Original Poster", "Online Player", "Open Party"})
gamerWords:Add("If someone is 'Buffing', they are:", {"Powering Up", "Working Out", "Cleaning Gear", "Taking Damage"}, 2)

local gamerWords2 = categoryManager.New("Gamer Words", "easy")
gamerWords2:Add("When devs weaken a strong weapon, they ___ it:", {"Nerf", "Buff", "Patch", "Hotfix"})
gamerWords2:Add("'Camping' in shooters means:", {"Staying in One Spot", "Cheating", "Co-op Mode", "Building Camps"})
gamerWords2:Add("A 'Clutch' is a:", {"Last-Second Win", "Car Part", "Team Carry", "Controller Glitch"})
gamerWords2:Add("If a player is trying to beat a game as fast as possible, they are attempting a ...", {"Speedrun", "Speed Challenge", "Time Trial", "Time attack"})
gamerWords2:Add("What is the act of pulling enemies away to fight them individually called?", {"Kiting", "Buffing", "Turtling", "Zerging"}, 2)

local streaming = categoryManager.New("Streaming Culture", "medium")
streaming:Add("'IRL' stands for:", {"In Real Life", "Internet Rules List", "Item Reward Level", "Instant Raid Loot"})
streaming:Add("The 'PogChamp' emote expresses:", {"Excitement", "Disappointment", "Anger", "Sadness"})
streaming:Add("A viewer who watches silently without chatting is called a:", {"Lurker", "NPC", "Nonchatter", "Sneaker"})
streaming:Add("You can Cheer to streamers using which currency?", {"Bits", "Coins", "Credits", "Super Chats"})
streaming:Add("What is the term for when a streamer sends their viewers to another live stream?", {"Raid", "Swap", "Relay", "Transfer"}, 2)

local computerHardware = categoryManager.New("Computer Hardware", "medium")
computerHardware:Add("What component is considered the 'brain' of a computer?", {"CPU", "RAM", "GPU", "HDD"})
computerHardware:Add("What does GPU stand for?", {"Graphics Processing Unit", "General Processing Unit", "Gaming Performance Unit", "Global Processing Unit"})
computerHardware:Add("What unit is computer memory (RAM) typically measured in?", {"Gigabytes", "Volts", "Hertz", "Watts"})
computerHardware:Add("What is the standard port for connecting a monitor?", {"HDMI", "USB", "Ethernet", "PS/2"})
computerHardware:Add("Which type of memory loses all its data when the computer is turned off?", {"RAM", "HDD", "SSD", "ROM"}, 2)

local ancientCivilizations = categoryManager.New("Ancient Civilizations", "medium")
ancientCivilizations:Add("Which ancient civilization had gladiator fights?", {"Romans", "Greeks", "Egyptians", "Chinese"})
ancientCivilizations:Add("Which ancient civilization built the pyramids of Giza?", {"Egypt", "Inca", "Rome", "Greece"})
ancientCivilizations:Add("What was the capital of the Roman Empire?", {"Rome", "Athens", "Alexandria", "Constantinople"})
ancientCivilizations:Add("Which civilization invented democracy?", {"Ancient Greece", "Rome", "Egypt", "Persia"}, 2)
ancientCivilizations:Add("Which ancient civilization invented paper?", {"Chinese", "Egyptians", "Greeks", "Persians"})

local worldRecords = categoryManager.New("World Records", "easy")
worldRecords:Add("What is the fastest land animal?", {"Cheetah", "Lion", "Horse", "Antelope"})
worldRecords:Add("Which book holds the record for being the most sold and translated in history?", {"The Bible", "The Lord of the Rings", "Harry Potter and the Sorcerer's Stone", "The Quran"})
worldRecords:Add("Which is the largest country by land area?", {"Russia", "China", "United States", "Canada"})
worldRecords:Add("Which is the highest mountain in the world?", {"Mount Everest", "K2", "Mount Kilimanjaro", "Mount Fuji"})
worldRecords:Add("What is the longest word in a major dictionary?", {"Pneumonoultramicroscopicsilicovolcanoconiosis", "Supercalifragilisticexpialidocious", "Hippopotomonstrosesquippedaliophobia", "Floccinaucinihilipilification"}, 2)

end -- End of quiz definitions

local function sortNames(names)
    table.sort(names, function(a, b) return string.lower(a) < string.lower(b) end)
    return names
end

local function getCategoryName(name)
    if not name or #name < 2 then return nil end
    local needle = string.lower(name)
    local exact = nil
    local match = nil
    for _, categoryName in ipairs(categoryOrder) do
        local lower = string.lower(categoryName)
        if lower == needle then
            exact = categoryName
            break
        end
        if string.sub(lower, 1, #needle) == needle then
            if match then return nil end
            match = categoryName
        end
    end
    return exact or match
end

local function getQuestions(categoryName, difficulty)
    local category = categories[categoryName]
    if not category then return nil end
    difficulty = difficulty and normalizeDifficulty(difficulty) or nil
    if difficulty and difficulty ~= "" then
        local questions = {}
        local buckets = category.difficulties[difficulty]
        if not buckets then return nil end
        for _, quiz in ipairs(buckets) do
            for _, q in ipairs(quiz) do
                table.insert(questions, q)
            end
        end
        return questions
    end
    return category.all
end

function ctx.getQuizCategories()
    return categories, categoryOrder
end

function ctx.findQuizCategory(name)
    return getCategoryName(name)
end

function ctx.getQuizCategoryQuestions(name, difficulty)
    local categoryName = getCategoryName(name)
    if not categoryName then return nil, nil end
    return getQuestions(categoryName, difficulty), categoryName
end

function ctx.getQuizCategoryDifficulties(name)
    local categoryName = getCategoryName(name)
    local category = categoryName and categories[categoryName]
    if not category then return {} end

    local difficulties = {}
    for difficulty in pairs(category.difficulties) do
        if difficulty ~= "" then
            table.insert(difficulties, difficulty)
        end
    end
    table.sort(difficulties, function(a, b) return a < b end)
    table.insert(difficulties, 1, "all")
    return difficulties
end

ctx.registerCommand({
    aliases = { "categories", "category", "cats", "topics" },
    info = "List built-in quiz categories",
    category = "Quiz",
    fn = function()
        local names = {}
        for _, name in ipairs(categoryOrder) do table.insert(names, name) end
        sortNames(names)
        ctx.BotChat("Categories: " .. table.concat(names, ", "))
    end,
})

ctx.registerCommand({
    aliases = { "start", "topic", "startcat" },
    args = "<category> [difficulty]",
    info = "Start a built-in category quiz",
    category = "Quiz",
    fn = function(args)
        if args == "" then
            ctx.BotChat("Usage: " .. ctx.settings.prefix .. "start <category> [difficulty]")
            return
        end

        local categoryArg = args
        local difficulty = nil
        local maybeCategory, maybeDifficulty = string.match(args, "^(.-)%s+(easy|medium|hard)$")
        if maybeCategory and maybeCategory ~= "" then
            categoryArg = maybeCategory
            difficulty = maybeDifficulty
        end

        local questions, categoryName = ctx.getQuizCategoryQuestions(categoryArg, difficulty)
        if not questions or #questions == 0 then
            ctx.BotChat("Category not found. Use " .. ctx.settings.prefix .. "categories")
            return
        end

        ctx.lastQuizData = questions
        ctx.BotChat("Loaded " .. categoryName .. " (" .. #questions .. " questions). Starting...")
        task.wait(1)
        if ctx.runQuiz then
            task.spawn(function() ctx.runQuiz(questions) end)
        else
            ctx.BotChat("Quiz engine is not ready yet")
        end
    end,
})

ctx.consoleLog("Legacy quiz categories loaded: " .. tostring(#categoryOrder) .. " categories")
