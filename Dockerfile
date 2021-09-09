FROM mcr.microsoft.com/dotnet/framework/sdk:3.5-windowsservercore-ltsc2019

#Set environment variables
ENV EMR_BIN="c:\src\BuildOutputHost"
ENV WIX="C:\Program Files (x86)\WiX Toolset v3.11\\"

WORKDIR "C:\Support"
COPY AssemblyVersionInfo.cs C:/Support/
COPY wix.reg C:/Support/
RUN reg import wix.reg
WORKDIR "C:\Common\DevFoundation\Src\Framework\FileServices\Certificate"
COPY CertificateInfo.cs C:/Common/DevFoundation/Src/Framework/FileServices/Certificate

#Visual Studio version
ARG target1="C:\Program Files (x86)\Microsoft Visual Studio\2019\BuildTools\MSBuild\Microsoft\WiX\v3.x"
WORKDIR ${target1}
COPY /VisualStudioVersion/wix.targets ${target1}

#MSBuild version
ARG target2="C:\Program Files (x86)\MSBuild\Microsoft\WiX\v3.x"
WORKDIR ${target2}
COPY /MSBuildVersion/wix.targets ${target2}
COPY /MSBuildVersion/wix200x.targets ${target2}
COPY /MSBuildVersion/wix2010.targets ${target2}

#Wix Folder copy
ARG target3="C:\Program Files (x86)\WiX Toolset v3.11/"
WORKDIR ${target3}
COPY /WiXToolset/ ${target3}

#Other copy
ARG target3="C:\Program Files (x86)\Reference Assemblies\Microsoft\Framework\.NETFramework\v4.5.2"
ARG target4="C:\Program Files (x86)\Reference Assemblies\Microsoft\Framework\.NETFramework\v4.6.1"
ARG target5="C:\Program Files (x86)\Microsoft Visual Studio\2019\BuildTools\MSBuild\Microsoft\VC\v160"
COPY Microsoft.VisualStudio.QualityTools.UnitTestFramework.dll ${target3}
COPY Microsoft.VisualStudio.QualityTools.UnitTestFramework.dll ${target4}
COPY Microsoft.Deployment.WindowsInstaller.dll ${target4}
WORKDIR "C:\Program Files (x86)\Microsoft Visual Studio\2019\BuildTools\MSBuild\Microsoft\VC/"
COPY /v160/ ${target5}
WORKDIR "C:\Program Files (x86)\Microsoft Visual Studio\2019\BuildTools\MSBuild\Microsoft\VC\v160"
RUN gacutil -i Microsoft.Build.CPPTasks.Common.dll

WORKDIR "C:\Program Files (x86)"
