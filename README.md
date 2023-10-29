# Getting up and running

comby only works on linux, so you will want to setup an Ubuntu 22.04 LTS release as the lab hhost.

## Windows Subsystem for Linux

I went through this locally at home and then tried running through it in the labs. Unfortunately the existing explorer pack builds don't support nested virtualization. It is ostensibly possible to get this up and running. However, it will require a Project Pack on Azure for this. That requires submitting a lab request. I'm avoiding that for now, but leaving this here in case I or someone else finds the time to chase up a request and then try this out. Note that it is possible to use 2 lab machines and vscode remote ssh connection to bridge them, which I'll cover later.

First get Ubuntu-22.04 up and running in WSL and set it as default. Once it is up and running proceed to [Ubuntu comby setup](#ubuntu-comby-setup).

First we need to enable virtualization. You must reboot after this

```
DISM /Online /Enable-Feature /All /FeatureName:Microsoft-Hyper-V
```

After reboot, run the following from a powershell terminal. Once the last command runs the terminal will be a shell inside the Ubuntu image running in WSL. Note: reboots may be required.

```
wsl --install
wsl --update
wsl --install -d Ubuntu-22.04
wsl -l -v
wsl -s Ubuntu-22.04
wsl -l -v
```

## Ubuntu comby setup

These are the steps to get comby up and running on the new Ubuntu build. First we will update the OS itself, then install tools needed including comby. Note that libev4 is an event loop library used by comby, so is a required dependency for it to work in the first place. jq is used for processing comby search results as json. You may not need jq depending on your scenario.

Run the following from a shell in Ubuntu.

```
sudo apt update
sudo apt install -y jq, libev4
bash <(curl -sL get-comby.netlify.app)
comby --help
```

## Using VSCode

If you are comfortable staying in a shell terminal the whole time, or know how to reconfigure the Ubuntu image to support windowing/desktop, then have at it (and please submit a PR to update this). My preference was to use VSCode. Since the WSL2 approach did not work in the labs I've taken another approach. I document this below in case you want to do the same.

Create a Windows Developer Explorer Pack host in addition to your Ubuntu one. When it is up and running start VSCode and install the Remote-SSH extension from the marketplace. After this is installed you can use the command pallette to run `Remote SSH: Add new SSH host`. This will walk you through a few prompts to set up your Ubuntu host. At the first prompt you should provide `username@ip-address` taking the username and ip-address from the lab portal web page on the jumphost (select the Ubuntu host). Next it will ask you to select the SSH configuration file to update. Select the default choice.

Now you can use the command pallette to run `Remote SSH: Connect Current Window to Host` and select the ip address of your Ubuntu host. It will ask for your password, which you can again get from the lab portal web page on the jumphost. This will connect the current VSCode intance on your Windows host to the Ubuntu host. From here you can use VSCode remote in the typical fashion.

## For testing with dotnet

I have written the initial example of comby usage to do some .net C# transformations using comby CLI fro a shell script. The examples will be expanded to cover other forms of usage. To run the .net samples will require an sdk install for build/test. In the following we install .net 7.0, you can run `sudo apt search dotnet-sdk` to see what other sdks are available for install. After this you will follow the typical .net developer workflow for linux.

```
sudo apt install -y dotnet-sdk-7.0
dotnet --info
```

### C# Example Shell Script

As noted above, the first example uses comby CLI in a shell script. This covers the most straightforward and basic usage. Later examples will show usage of rules, config driven usage and hopefully leveraging Type Information as a Service.

All the examples take a public github repository that uses Moq (which should not be used due to user data exfiltration in certain releases) to use NSubstitube instead. It's not relevant to the example, but this repository is for a basic Inversion of Control (Dependency Injection) Container named [IoCContainer](https://github.com/DevTeam/IoCContainer). To begin with we need to clone the repo locally and build/test with existing Moq to ensure we start from a clean slate. Execute the following from your Ubuntu shell.

```
git clone https://github.com/DevTeam/IoCContainer.git
sed -i 's/net7.0;net48;net40/net7.0/g' Directory.Build.props
dotnet build IoC.sln
dotnet test IoC.Tests/IoC.Tests.csproj
```

Note: if there are issues during package restore and you are running in a shell on Ubuntu then opening a new shell after the install of .net sdk should resolve the issue. Also, the `sed` command above will remove .net Framework test target, which won't run on linux.

Once we observe all tests are passing we will run [this script](https://github.com/mgasca/TransformationExploration/blob/main/comby/MoveMoqToNSub.sh), which implements the migration using comby. Note: this is not a full featured migration. I have only implemented what is necessary for this single repo. Of course the script may be expanded for broader coverage. If you would like to expand coverage yourself (or cleanup existing as it was written very quickly with no refactoring) feel free to submit a PR.

```
wget https://raw.githubusercontent.com/mgasca/TransformationExploration/main/comby/MoveMoqToNSub.sh
chmod +x MoveMoqToNSub.sh
./MoveMoqToNSub.sh
```

Once the migration completes build and run tests again and they should all be passing using NSubstitute.

### Same example but with TOML

**Still a work in progress - following is not yet working**
comby CLI also supports specifying the matches, rewrites and rules in a configuration file. The file format used is TOML. I have converted the script from the previous section into 3 separate .toml files. When using a config file you must still provide the file name or extension at the command line. This is why it was split to 3 tomls, one for .props files, a second for .csproj files and the third for all the C# source code files (.cs).

```
wget https://raw.githubusercontent.com/mgasca/TransformationExploration/main/toml/update-props.toml
wget https://raw.githubusercontent.com/mgasca/TransformationExploration/main/toml/update-csproj.toml
wget https://raw.githubusercontent.com/mgasca/TransformationExploration/main/toml/moq-2-nsub.toml
comby -i -config update-props.toml -f .Build.props -match-only -matcher .cs -d .
comby -matcher .cs -d IoC.Tests -i -config update-csproj.toml -f .csproj
comby -matcher .cs -d IoC.Tests -i -config moq-2-nsub.toml -f .cs
```
