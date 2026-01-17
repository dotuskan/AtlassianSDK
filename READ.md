* Copy directory to your C:\ drive

[install-the-atlassian-sdk-on-a-windows-system](https://developer.atlassian.com/server/framework/atlassian-sdk/install-the-atlassian-sdk-on-a-windows-system)

`copy -R .\atlassian-plugin-sdk-9.1.1\ C:\`

* Open **Control Panel** > **System** >**Advanced System Settings.**
* On the **Advanced** tab click **Environment Variables.**
* Locate the **System variables** section and click **New.**
* Enter ATLASSIAN_PLUGIN_SDK_HOME in the **Variable name** field and paste the folder path you copied to into the **Variable value** field.
* Click **OK** to close the dialog.
* Click on **Path** variable in the **System variables ** section and click **Edit** .
* Click **New **and type `%ATLASSIAN_PLUGIN_SDK_HOME%\bin `in the available space.
* Lock the desktop and relogin

[installer-changes-path-variable-changes-dont-show-up-in-command-shell](https://stackoverflow.com/questions/40311/installer-changes-path-variable-changes-dont-show-up-in-command-shell)
