// To make looking up keys with a script easier, if you add terse=1  to the URL, the response will contain only the key you asked for.
// If it was not found, it will return NULL_KEY. Example script:

// The bookshelves are rezzed directly in front of the rezzer, and will continue to be rezzed in a horizontal line until finished. After that, they can be moved around as necessary. It's recommended that a copy of each bookshelf is taken into inventory, for easier transport, and as a backup. After being rezzed, the size properties are adjusted to the user's specifications.

// Each bookshelf is filled with books in the order they are listed in the tab-delimited file. Currently, all books are the same dimensions, though support for variable size books depending on the length of the file is planned for the future. Each book contains a single random color for its covers and spine, and if a cover texture is indicated, that replaced both the front and back. Support for separate front and back covers is also planned for the future. Each book contains a script for rendering the dynamic textures it needs. If a cover image is not indicated, one will be generated from text and include the title and author.

string url = "http://ebooks.wsd.net/json.php"; // name2key url
key reqid;                                     // http request id
float bookshelfLength = 5.0;    // Note that this includes the extra space occupied by the frame walls, so the actual available shelf space is 0.5m smaller. 
float bookshelfFrameSize = 0.5;
integer shelvesPerBookshelf = 6;
vector bookSize = <0.050, 0.300, 0.218>;
float spaceBetweenBooks = 0.065;
float shelfHeight = 0.40;
list rezzedBooks;
integer libraryChannel = -500;    // The channel for listening to the rezzed books.

string strReplace(string src)
{
    integer is_HTML = 0;
    string result = "";
    string s;
    integer i;
    for (i=0; i<llStringLength(src); i++)
    {
      s = llGetSubString(src,i,i); 
      if (s == "<")
      {
            is_HTML = 1;
      }
      if (is_HTML == 0 && s != "\n")
        {
            result += s; 
        }
      if (s == ">")
        {
            is_HTML = 0;
        }
    }
    return result;
}

draw_text(string title, string author)
{
    string drawList = "MoveTo 40,80; PenColour RED; FontSize 48; Text " + title + ";";
    drawList += "PenColour RED; FontName Times New Roman; MoveTo 40,900; Text " + author + ";";
    osSetDynamicTextureData("", "vector", drawList, "1024", 0); //<<ERROR ON THIS LINE
}


       
rezShelves(list allbooks)
{
    // Create bookshelves as each book is processed, and dynamically determine how many book shelves we will need as we go.from the custom specifications. Leave 0.01m of space between each book.
    integer bookIndex;
    integer totalBooks = llGetListLength(allbooks);
    float bookPositionX = 0;
    integer bookPositionShelf = 0;
    integer shelfCount = 0;
    integer bookshelfCount = 0;

    // Calculate how many books we need. Right now we're just using the same bookshelf, so we technically don't need to do this and could just hardcode values, but at some point in the future, this script will allow dynamically resizing bookshelves. By calculating the book count per shelf, we'll at least be prepared for that, at the cost of just a small amount of extra memory usage.
    // TODO: The math might be wrong here. Logically, I don't think the * 2 should be needed, but it seems like it produces the best results anyway.
    integer booksPerShelf = llFloor((bookshelfLength - bookshelfFrameSize) / ((bookSize.x + spaceBetweenBooks) * 2));

    vector bookshelfOffset = <3.0, -5.0, 0.0>;
    vector bookOffset = <3.0, 5.2, 1.0>;
    vector myPos = llGetPos();
    rotation myRot = llGetRot();    vector offset;
    vector rezPos;
    vector rezVel;
    rotation rezRot;

    llOwnerSay("Total books: " + (string) totalBooks);
    for (bookIndex = 0; bookIndex < totalBooks; bookIndex++)
    {
        // If we're starting a new bookshelf, we need to rez it. Populate each shelf until (booksPerShelf * shelvesPerBookshelf) is reached, then rez a whole new bookshelf.
        if (bookIndex % (booksPerShelf * shelvesPerBookshelf) == 0)
        {
            bookshelfOffset += <0.0, 2.0, 0.0>;
            rezPos = myPos + bookshelfOffset * myRot;
            rezVel = ZERO_VECTOR * myRot;
            rezRot = llEuler2Rot(<270, 180, 0> * DEG_TO_RAD) * myRot;

            // Rez the bookshelf.
            // llOwnerSay("Creating Bookshelf");
            llRezObject("Bookshelf", rezPos, rezVel, rezRot, (10 + shelfCount));

            bookshelfCount = 0;
            shelfCount = 0;
        }

        // Determine which shelf we're on and which position to place the book. If we're starting a new shelf, increment the shelfCount, so the books get positioned lower on the bookshelf.
        if (bookIndex % booksPerShelf == 0)
        {
            // llOwnerSay("New shelf");
            shelfCount++;
            bookOffset = <0.0, 0.0, (shelvesPerBookshelf - (shelfCount * shelfHeight))>;
            rezPos = myPos + bookOffset * myRot;
        }

        integer stateParam = 1000 + bookIndex;
        // The stateParam is used as the unique identifier for the book (instead of the key). The book, after rezzed, will talk back to the Virtual Library rezzer and request the book information, using the stateParam. The Virtual Library rezzer listens for these requests and uses the rezzedBooks list (which includes the same data as allBooks plus the addition of the stateParam) to return the requested data.
//    list currentBook = llParseString2List(stateParam + "\t" + llList2String(allbooks, bookIndex), ["\t"], []);
        string currentBook = "<" + stateParam + ">," + llList2String(allbooks, bookIndex);
        rezzedBooks += currentBook;

        // Rez a book.
        // llOwnerSay("Rezzing book " + (string) bookIndex);
        llRezObject("Book",
            rezPos + <((bookIndex % booksPerShelf) * (bookSize.x + spaceBetweenBooks)) - 1, -0.25, (0.24 * (shelvesPerBookshelf - (shelfCount * shelfHeight))) - 5.74> + bookshelfOffset,
            rezVel, (llEuler2Rot(<0, 0, 0> * DEG_TO_RAD) * myRot), (stateParam));
    }
}



default
{
    state_entry()
    {
        llListen(libraryChannel, "", NULL_KEY, "");
    }

    // When a book is rezzed, it contains only page textures on the sides, but no cover or spine. These data are transmitted to the book through a message. Each book has to request the data through a script that uses the stateParam to identify the book's attributes. The information is transmitted through a tab-delimited string, and sets the cover, spine, inside text, teleport destination, and any other attributes accordingly.
    listen(integer channel, string name, key id, string message)
    {
        integer requestedBookId = (integer) message;
        // string requestedBook = llParseString2List(message, ["\t"], []);
    
        // We know that the stateParams started at 1000 when they were added to the rezzedBooks list, so we just have to subtract 1000 from the requested stateParam.
        string requestedBook = llList2String(rezzedBooks, (requestedBookId - 1000));

        // Each book is given its own negative channel, based on the stateParam. We need to send the book information back on that channel.
        string stateParam = llList2String(llCSV2List(requestedBook), 0);

        // Kind of strange that we'd have to get rid of the < and > manually, but here we go.
        stateParam = llGetSubString(stateParam, 1, -2);

        integer bookChannel = (integer) stateParam * -1;

        llSay(bookChannel, requestedBook);
    }

    touch_start(integer num)
    {
        reqid = llHTTPRequest( url, [], "" );
    }

    http_response(key id, integer status, list meta, string body)
    {
        list allbooks;

        if ( id != reqid )
            return;
        if ( status == 499 )
            llOwnerSay("name2key request timed out");
        else if ( status != 200 )
            llOwnerSay("The Internet exploded!!");
        else if ( (key)body == NULL_KEY )
            llOwnerSay("null");
        else
        {
            list books;
            books = llParseString2List(body, ["\n"], []);
            integer i;
            integer length = llGetListLength(books);
            for (i = 0; i < length; i++)
            {
//              list attributes = llParseString2List(llList2String(books, i), ["\t"], []);
                list attributes = llList2String(books, i);
                allbooks += attributes;
                // llOwnerSay("Scanning book " + (string) i);
            }
        }
        rezShelves(allbooks);
    }
}
