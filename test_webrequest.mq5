//+------------------------------------------------------------------+
//| Test WebRequest Connection                                        |
//+------------------------------------------------------------------+
#property copyright "Your Name"
#property link      ""
#property version   "1.00"
#property script_show_inputs

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
{
   Print("=== WebRequest Test ===");
   
   // Test 1: Simple GET request
   Print("Test 1: Simple GET request to backend health endpoint");
   string url1 = "https://forex-bot-ffiu.onrender.com/health";
   string headers1 = "";
   uchar post1[], result1[];
   string response1;
   
   int res1 = WebRequest("GET", url1, headers1, 15000, post1, result1, response1);
   Print("Result 1: HTTP ", res1);
   Print("Response 1: ", response1);
   
   // Test 2: POST request with JSON
   Print("\nTest 2: POST request to analyze endpoint");
   string url2 = "https://forex-bot-ffiu.onrender.com/analyze";
   string headers2 = "Content-Type: application/json\r\n";
   string postData2 = "{\"price_data\":[1.2345,1.2346,1.2347],\"symbol\":\"Boom 1000 Index\"}";
   uchar post2[], result2[];
   string response2;
   
   StringToCharArray(postData2, post2);
   
   int res2 = WebRequest("POST", url2, headers2, 15000, post2, result2, response2);
   Print("Result 2: HTTP ", res2);
   Print("Response 2: ", response2);
   
   // Test 3: Check if WebRequest is enabled
   Print("\nTest 3: Checking WebRequest status");
   Print("WebRequest enabled for forex-bot-ffiu.onrender.com: ", 
         WebRequest("GET", "https://forex-bot-ffiu.onrender.com/health", "", 5000, post1, result1, response1) != -1);
   
   Print("=== Test Complete ===");
} 