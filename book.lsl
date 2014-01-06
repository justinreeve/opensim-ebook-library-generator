integer libraryChannel = -500;
list bookDetails;
key reqId;
string retrievePDFURL = "http://books.weber.k12.ut.us/pdf2png/index.php?pdf=";

// When we're applying the cover textures, we're both using the graphic on the front and back, and writing text on the spine. It would be beneficial if the spine at least was a similar color to the cover. So the same graphic as the cover is used, but at 50% transparency, then the spine text is drawn over the top.
fillBook()
{
    string mode = llGetSubString(llList2String(bookDetails, 1), 1, -2);
    string title = llGetSubString(llList2String(bookDetails, 2), 1, -2);
    string author = llGetSubString(llList2String(bookDetails, 3), 1, -2);
    string coverURL = llGetSubString(llList2String(bookDetails, 4), 1, -2);
    string textURL = llGetSubString(llList2String(bookDetails, 5), 1, -2);
    string URLTexture = osSetDynamicTextureURL("", "image", coverURL, "", 1200); 
    string pagesTexture = "d7ab0e84-041e-49e4-90a8-33f393d98443";

    // getText();

    // llOwnerSay(title + " " + author + " " + coverURL + " " + textURL + " " + URLTexture);
    if (llStringLength(URLTexture) > 0) 
    {
        llSetTexture(URLTexture, 0);
        llSetTexture(URLTexture, 3);
        llSetTexture(URLTexture, 5);
        llSetTexture(pagesTexture, 0);
        llSetTexture(pagesTexture, 3);
        llSetTexture(pagesTexture, 5);
        // llSetAlpha(0.5, 1);
    }

    // Create the PDF record and get back the id. Do it in "noconvert" mode.
    reqId = llHTTPRequest(retrievePDFURL + textURL + "&mode=noconvert", [], "");
}
        
getText()
{
//    string drawData;
//        drawData += "PenColour Teal; FillRectangle 1024, 512;";
//        drawData += "PenColour PowderBlue;";
//        drawData += "MoveTo 40, 30; FontSize 6; Text 2000 UTC:;";
//        drawData += "MoveTo 250, 30; Text Speed Build Competition;";
//        drawData += "MoveTo 40, 70; Text 0120 UTC:;";
//        drawData += "MoveTo 250, 70;Text Working On Sign;";
//        drawData += "MoveTo 40, 110; Text 0500 UTC:;";
//        drawData += "MoveTo 250, 110; Text Going To Sleep!;";
//        drawData += "MoveTo 40, 150; Text 0600 UTC:;";
//        drawData += "MoveTo 250, 150; FontProp B,I;Text Waking Up!;";
//        drawData += "FontProp R;";
//        drawData += "MoveTo 40, 190; Text Have a great day!!;";
//        drawData += "PenCap end,arrow; LineTo 50,250; MoveTo 50,250;";
//        osSetDynamicTextureData("", "vector", drawData, "width:128,height:512", 0);        
}

default
{
    state_entry()
    {
        // Request the book information.
        integer startParam = llGetStartParameter();
        integer bookChannel = startParam * -1;
        // llOwnerSay("Book is listening on channel: " + (string) bookChannel);
        if (bookChannel != 0)
        {
            llListen(bookChannel, "", NULL_KEY, "");
            llSay(libraryChannel, (string) startParam);
        }
        else if (llGetObjectDesc() != "")
        {
            list bookDetails = llCSV2List(llGetObjectDesc());
        }
    }

    on_rez(integer startParam)
    {
        llResetScript();
    }

    listen(integer channel, string name, key id, string message)
    {
        // llOwnerSay("Book receiving message: " + message);
        bookDetails = llCSV2List(message);

        // TODO?: Change the book's description to the attributes CSV, in case an instance occurs where we need to get the information without the rezzer handy.
        // llSetObjectDesc(llDumpList2String(bookDetails, ","));

        fillBook();
    }

    http_response(key id, integer status, list meta, string body)
    {
        if (id != reqId)
            return;
        if (status == 499)
            llOwnerSay("name2key request timed out");
        else if (status != 200)
            llOwnerSay("the internet exploded!!");
        else
        {
            llOwnerSay(body);

            // Retrieve the book id and save it to the description.
            if (llGetSubString(body, 0, 7) == "Success")
            {
                string bookId = llGetSubString(body, 7, -1);

                // Change the book's description to the book id.
                llSetObjectDesc(body + " " + bookId);
            }
        }   
    }
}
