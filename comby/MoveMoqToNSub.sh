#! /bin/bash
echo Creating new branch to do migration on
git checkout -b moq-2-nsub-migrate

# Change packages
echo Swapping Packages from Moq to NSubstitute
comby -matcher .cs -i \
'<TestTargetFrameworks>net7.0;net48;net40</TestTargetFrameworks>' \
'<TestTargetFrameworks>net7.0;net48</TestTargetFrameworks>' .Build.props
comby -matcher .cs -d IoC.Tests -i \
'<PackageReference Include="Moq" Version=":[version]" />' \
'<PackageReference Include="NSubstitute" Version="5.1.0" />' .csproj
comby -matcher .cs -d IoC.Tests -i \
'Include="Castle.Core" Version=":[version]"' 'Include="Castle.Core" Version="5.1.1"' .csproj

# update namespaces
echo Swapping using statement
comby -matcher .cs -d IoC.Tests -i 'using Moq;' 'using NSubstitute;' .cs

# Mock creation and access
echo Transforming declaration and instantiation
comby -matcher .cs -d IoC.Tests -i 'Mock.Of' 'Substitute.For' .cs
comby -matcher .cs -d IoC.Tests -i 'new Mock<:[type]>(:[parms])' 'Substitute.For<:[type]>(:[parms])' .cs
# would be for declarations, but seems var is used everywhere here
comby -matcher .cs -d IoC.Tests -i 'Mock<:[type]> :[name] =' ':[type] :[name] =' .cs
comby -matcher .cs -d IoC.Tests -i ':[[mock]].Object' ':[[mock]]' .cs
# deal with mocking func factories, moq defaults to new every time, not nsub.
# so also need to fix this up
comby -matcher .cs -d IoC.Tests -i \
'Func<:[[type]]> :[[name]] = Substitute.For<:[[type]]>;'  \
'Func<:[[type]]> :[[name]] = Substitute.For<Func<:[[type]]>>();
:[[name]]().Returns(i => Substitute.For<:[[type]]>());' .cs

# Mock setup
echo Transforming setups
comby -matcher .cs -d IoC.Tests -i \
':[[var]].Setup(:[arg] => :[arg].:[method](:[mparm])).Callback<:[cType]>(:[x] => :[pre]:[x].:[post]);' \
':[[var]].When(:[arg] => :[arg].:[method](:[mparm])).Do(:[x] => :[pre]:[x].Arg<:[cType]>().:[post]);' .cs
comby -matcher .cs -d IoC.Tests -i ':[[var]].Setup(:[action]).Throws' ':[[var]].When(:[action]).Throw' .cs
comby -matcher .cs -d IoC.Tests -i \
':[[var]].Setup(:[arg] => :[arg].:[method](:[mparm]))' ':[[var]].:[method](:[mparm])' .cs
comby -matcher .cs -d IoC.Tests -i ':[[var]].SetupGet(:[arg] => :[arg].:[prop])' ':[[var]].:[prop]' .cs

# Verification
echo Transforming verifications
comby -matcher .cs -d IoC.Tests -i \
':[[var]].Verify(:[a] => :[a].:[method](:[args]), Times.Once)' ':[[var]].Received().:[method](:[args])' .cs
comby -matcher .cs -d IoC.Tests -i \
':[[var]].Verify(:[a] => :[a].:[method](:[args]), Times.Exactly(:[times]))' \
':[[var]].Received(:[times]).:[method](:[args])' .cs
comby -matcher .cs -d IoC.Tests -i \
':[[var]].Verify(:[a] => :[a].:[method](:[args]))' ':[[var]].Received().:[method](:[args])' .cs

# Argument matchers, must be run in this order
echo Transforming arg matchers
comby -matcher .cs -d IoC.Tests -i 'It.IsRegex(:[regex])' 'Arg.Is<string>(i => Regex.IsMatch(i, :[regex]))' .cs
comby -matcher .cs -d IoC.Tests -i 'It.IsAny' 'Arg.Any' .cs
comby -matcher .cs -d IoC.Tests -i 'It.Is' 'Arg.Is' .cs

echo Adding using for Regex where needed
output=$(comby -match-only -json-lines -matcher .cs -d IoC.Tests -i 'Arg.Is<string>(i => Regex.IsMatch(i, :[regex]))' '' .cs)
files=$(jq '.uri' <<< $output)
for f in $files
do
  noquotes=$(echo $f | tr -d '"')
  output=$(comby -match-only -json-lines -matcher .cs -d IoC.Tests -i 'using System.Text.RegularExpressions;' '' $noquotes)
  if [ -z $output ]
  then
    echo "using System.Text.RegularExpressions;"|cat - $noquotes > /tmp/out && mv /tmp/out $noquotes
  fi
done
echo ---------------------------------------
echo To build/run modified tests use:
echo dotnet test IoC.Tests/IoC.Tests.csproj