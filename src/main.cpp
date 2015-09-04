/*
 * (c) Copyright Ascensio System SIA 2010-2016
 *
 * This program is a free software product. You can redistribute it and/or
 * modify it under the terms of the GNU Affero General Public License (AGPL)
 * version 3 as published by the Free Software Foundation. In accordance with
 * Section 7(a) of the GNU AGPL its Section 15 shall be amended to the effect
 * that Ascensio System SIA expressly excludes the warranty of non-infringement
 * of any third-party rights.
 *
 * This program is distributed WITHOUT ANY WARRANTY; without even the implied
 * warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR  PURPOSE. For
 * details, see the GNU AGPL at: http://www.gnu.org/licenses/agpl-3.0.html
 *
 * You can contact Ascensio System SIA at Lubanas st. 125a-25, Riga, Latvia,
 * EU, LV-1021.
 *
 * The  interactive user interfaces in modified source and object code versions
 * of the Program must display Appropriate Legal Notices, as required under
 * Section 5 of the GNU AGPL version 3.
 *
 * Pursuant to Section 7(b) of the License you must retain the original Product
 * logo when distributing the program. Pursuant to Section 7(e) we decline to
 * grant you any rights under trademark law for use of our trademarks.
 *
 * All the Product's GUI elements, including illustrations and icon sets, as
 * well as technical writing content are licensed under the terms of the
 * Creative Commons Attribution-ShareAlike 4.0 International. See the License
 * terms at http://creativecommons.org/licenses/by-sa/4.0/legalcode
 *
*/

#include <QFile>
#include <QDir>
#include <QTranslator>
#include <QStandardPaths>
#include <QLibraryInfo>
#include "mainwindow.h"

//#include "cefapplication.h"
#include "cmyapplicationmanager.h"
#include "shlobj.h"

#include <QDebug>
#include <QFileInfo>
#include <QSettings>
#include <QScreen>


byte g_dpi_ratio = 1;
QString g_lang;

int main( int argc, char *argv[] )
{
    QString user_data_path = QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation) + "/ONLYOFFICE/DesktopEditors";

    auto setup_paths = [user_data_path](CAscApplicationManager * manager) {
        WCHAR szPath[MAX_PATH];
        std::wstring sAppData(L"");
        if ( SUCCEEDED(SHGetFolderPathW(NULL, CSIDL_COMMON_APPDATA, NULL, 0, szPath)) ) {
            sAppData = std::wstring(szPath);
            NSCommon::string_replace(sAppData, L"\\", L"/");
            sAppData += L"/ONLYOFFICE/DesktopEditors";
        }

        QString app_path = QCoreApplication::applicationDirPath();

        if (sAppData.size() > 0) {
            manager->m_oSettings.SetUserDataPath(sAppData);
            manager->m_oSettings.cookie_path = (user_data_path + "/data").toStdWString();
            manager->m_oSettings.fonts_cache_info_path = (user_data_path + "/data/fonts").toStdWString();

            QDir().mkpath(QString().fromStdWString(manager->m_oSettings.fonts_cache_info_path));
        } else {
            manager->m_oSettings.SetUserDataPath(user_data_path.toStdWString());
        }

        manager->m_oSettings.spell_dictionaries_path = (app_path + "/Dictionaries").toStdWString();
    };

    bool bIsChromiumSubprocess = false;
    for (int i(0); i < argc; ++i) {
        if ((0 == strcmp("--type=gpu-process", argv[i])) ||
                    (0 == strcmp("--type=renderer", argv[i]))) {
            bIsChromiumSubprocess = true;
            break;
        }
    }

    if ( bIsChromiumSubprocess ) {
        QApplication aa(argc, argv);
        CApplicationCEF oCef;
        CAscApplicationManager oManager;

        setup_paths(&oManager);

        oCef.Init_CEF(&oManager);
        return aa.exec();
    }

#ifdef _WIN32
    LPCTSTR mutex_name = (LPCTSTR)QString("TEAMLAB").data();
    HANDLE hMutex = CreateMutex(NULL, FALSE, mutex_name);

    GetLastError() == ERROR_ALREADY_EXISTS && (hMutex = NULL);
#endif

    QApplication app(argc, argv);
    CApplicationCEF* application_cef = new CApplicationCEF();
    QSettings reg_system(QSettings::SystemScope, "ONLYOFFICE", APP_NAME);
    QSettings reg_user(QSettings::NativeFormat, QSettings::UserScope, "ONLYOFFICE", APP_NAME);
    reg_user.setFallbacksEnabled(false);

    // read setup language and set application locale
    g_lang = reg_system.value("lang").value<QString>();
    QTranslator tr;
    if (g_lang.length()) {
        tr.load(g_lang, ":/langs/langs");
        app.installTranslator(&tr);
    }

    // read installation time and clean cash folders if expired
    if (reg_system.contains("timestamp")) {
        QDateTime time_istall, time_clear;
        time_istall.setMSecsSinceEpoch(reg_system.value("timestamp", 0).toULongLong());

        bool clean = true;
        if (reg_user.contains("timestamp")) {
            time_clear.setMSecsSinceEpoch(reg_user.value("timestamp", 0).toULongLong());

            clean = time_istall > time_clear;
        }

        if (clean) {
            reg_user.setValue("timestamp", QDateTime::currentDateTime().toMSecsSinceEpoch());
            QDir(user_data_path + "/data/fonts").removeRecursively();
        }
    }


    CAscApplicationManager * pApplicationManager = new CMyApplicationManager();
    setup_paths(pApplicationManager);
    pApplicationManager->CheckFonts();

    application_cef->Init_CEF(pApplicationManager);

    app.setAttribute(Qt::AA_UseHighDpiPixmaps);
#ifdef _WIN32
    g_dpi_ratio = app.primaryScreen()->logicalDotsPerInch() / 96;
#else
    g_dpi_ratio = app.devicePixelRatio();
#endif

    QByteArray css;
    QFile file;
    foreach(const QFileInfo &info, QDir(":styles/res/styles").entryInfoList(QStringList("*.qss"), QDir::Files)) {
        file.setFileName(info.absoluteFilePath());
        if (file.open(QIODevice::ReadOnly | QIODevice::Text)) {
            css.append(file.readAll());
            file.close();
        }
    }

    if (g_dpi_ratio > 1) {
        file.setFileName(":styles@2x/styles.qss");
        if (file.open(QIODevice::ReadOnly | QIODevice::Text)) {
            css.append(file.readAll());
            file.close();
        }
    }


    if (css.size()) app.setStyleSheet(css);

    // Font
    QFont mainFont = app.font();
    mainFont.setStyleStrategy( QFont::PreferAntialias );
    app.setFont( mainFont );

    // Background color
    HBRUSH windowBackground = CreateSolidBrush( RGB(49, 52, 55) );

    // Create window
    QRect _window_rect = reg_user.value("position",
                                QRect(100, 100, 1324 * g_dpi_ratio, 800 * g_dpi_ratio)).toRect();

    QRect _screen_size = app.primaryScreen()->availableGeometry();
    if (_screen_size.width() < _window_rect.width())
        _window_rect.setWidth(_screen_size.width()), _window_rect.setLeft(0);

    if (_screen_size.height() < _window_rect.height())
        _window_rect.setHeight(_screen_size.width()), _window_rect.setTop(0);

    CMainWindow window( &app, windowBackground, _window_rect, pApplicationManager );
    window.setMinimumSize( 800*g_dpi_ratio, 600*g_dpi_ratio );


    ((CMyApplicationManager *)pApplicationManager)->setMainPanel(window.mainPanel);

    // Launch
    app.exec();

    // release all subprocesses
    pApplicationManager->CloseApplication();

    delete application_cef;
    delete pApplicationManager;

#ifdef _WIN32
    if (hMutex != NULL) {
        CloseHandle(hMutex);
    }
#endif
}