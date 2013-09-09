/*
** Copyright (c) 2013, Cthulhu / Cthulhu@GBITnet.com.br
** All rights reserved.
**
** Redistribution and use in source and binary forms, with or without
** modification, are permitted provided that the following conditions are met:
**
** 1. Redistributions of source code must retain the above copyright notice, this
**    list of conditions and the following disclaimer.
** 2. Redistributions in binary form must reproduce the above copyright notice,
**    this list of conditions and the following disclaimer in the documentation
**    and/or other materials provided with the distribution.
**
** THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
** ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
** WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
** DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
** ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
** (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
** LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
** ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
** (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
** SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

class DMFFAGFx_HUDManager extends AOCGFx_HUDManager;

/** 
 *  Process the initialization of views and other items here.
 */
event bool WidgetInitialized(name WidgetName, name WidgetPath, GFxObject Widget)
{

    local bool bResult;

    bResult = false;

    switch(WidgetName)
    {
  
        case ('HUDMain'):

            if (MainHUD == none)
            {

                MainHUD = AOCView_HUD_Main(Widget);
                ConfigureView(MainHUD, WidgetName, WidgetPath);
                ConfigureViewForDisplay(MainHUD);
                MainHUD.PostConfigureWidgetInit();
                bResult = true;

            }

            break;

        case ('Scoreboard'):

            if (Scoreboard == none)
            {

                Scoreboard = DMFFAView_HUD_Scoreboard(Widget);
                ConfigureView(Scoreboard, WidgetName, WidgetPath);
                Scoreboard.PostConfigureWidgetInit();
                bResult = true;

            }

            break;

    }

    return bResult;

}

DefaultProperties
{

    // Views.
    WidgetBindings.Remove((WidgetName="Scoreboard", WidgetClass=class'AOCView_HUD_Scoreboard'))
    WidgetBindings.Add((WidgetName="Scoreboard", WidgetClass=class'DMFFAView_HUD_Scoreboard'))

}