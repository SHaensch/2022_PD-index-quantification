@ String (visibility=MESSAGE, value="PDI-Quant - Sebastian Hänsch                                                   ") topMsg
#@ String (visibility=MESSAGE, value="  ") Empty
#@ String (label = "Specify if it new format (3Channel, LSM900, nyquist sampled) or old format (2Channel, spinning disc). See script header for details!", choices={"2channel", "3channel"}, value = "2channel", style="listBox") ChannelCount
#@ File (label = "Specify folder with collection of images", style = "directory") origDir
#@ Boolean(label = "I want to try channel shift correction?", value = false) ChannelCorrection
#@ Boolean(label ="I want to try estimate the median anilin background and subtract it (at least 10 images needed)?", value = false) MedianBackground
#@ Boolean(label = "I want to use a median filter for more robust PD definition? (default off)", value = false) PreMedian
#@ String (label = "Median factor before PD (default 0 AT NYQUIST SAMPLING LSM900, 0 for Spinning disc at 1024x1024 [px])?", value = "0") PDMedian
#@ String (label = "Multiplikator for PD size (default 1.5 AT NYQUIST SAMPLING LSM900 [px], 1 for Spinning disc at 1024x1024 )?", value = "1.5") PDSizeOffset
#@ String (label = "Median factor before defining background areas (default 25 AT NYQUIST SAMPLING LSM900 [px], 10 Spinning disc at 1024x1024 )?", value = "25") BGMedian
#@ String (label = "Local threshold factor for background (default 25 AT NYQUIST SAMPLING LSM900 [px], 15 Spinning disc at 1024x1024 )?", value = "25") LocalThreshold
#@ String (label = "Smoothing factor for the background binaries (default 4 at AT NYQUIST SAMPLING LSM900 & Spinning disc at 1024x1024 [px])?", value = "4") MaskSmoothing
#@ String (label = "Dilation factor for for background outline (default 5 AT NYQUIST SAMPLING LSM900, 3 Spinning disc at 1024x1024 [px])?", value = "5") MaskDilation
#@ String (label = "File format (e.g. .tif or .czi?", value = ".czi") InputFormat
#@ Boolean(label ="I want to read out parameter from the metadata (just LSM900 so far V1.20 and later)?", value = false) MetaRead
#@ String (label = "Choose a default autothreshold to start with PD-Identification", choices={"Huang", "Intermodes", "IsoData", "IJ-IsoData", "Li", "MaxEntropy", "Mean", "MinError", "Minimum", "Moments", "Otsu", "Percentile", "RenyiEntropy", "Shanbhag", "Triangle", "Yen"}, value = "Yen", style="listBox") AutoThres
#@ Boolean(label = "I want to speed up by hiding active processing?", value = false) BatchSpeed 
@ String (visibility=MESSAGE, value="Click OK to Proceed -->                                                                             ") botMsg

// 	Last update: 			20211118_AG_Frommer_Jona_SymPor_PDI-Quant_V1_23
//	Main author: 			Sebastian Hänsch, CAI - Center for Advanced Imaging - HHU
//	Modification author: 	
//	
//	--- Please consider appropriate acknowledgement and/or coauthorship, if this macro is notably contributing to the success of a publication ---
//
//					Description:	Quantification PD-indices in N.benthamiana, giving options for some corrections.
//					
//					Input: 	Must be a 3-Channel image (initially designed for Olympus SpinningDisc data, later added LSM900 compatibility). 
//							Channel1: Signal of interest.
//							Channel2: Annilin-Signal showing stained PD-Structures and background signal of the cell periphery. 
//							Channel3: Periphery-Signal (or any similar background-staining, outlining the periphery) 
//							In the best case, intensities / settings should not vary 
//							OR:	Must be a 2-Channel image (initially designed for Olympus SpinningDisc data, later added LSM900 compatibility). 
//							Channel1: Signal of interest.
//							Channel2: Annilin-Signal showing stained PD-Structures and background signal of the cell periphery. 
//							
//					Output: Returns folder with images of results with color coded regions next to the originals.
//							Also cropped views of the user choosen ROIs are saved in terms of reproducability (V1.20)
//							txt. file with detailed results per image
//							txt. file with results of all analized samples of a folder
//							txt. file with the documented options
//							
//					Dependencies: For channel registration: Turbostack-Reg and Multistackreg MUST be installed as plugins (http://bradbusse.net/downloads.html & http://bigwww.epfl.ch/thevenaz/turboreg/)
//	
//					Last modification: 	/SH 20210315 V.1.9 Set up everything so far and putting up first analysis for demonstration
//										/SH 20210601 V.1.10 bugfix, new preprocessing, limiting to double square to make it easier, eliminating all other tested PD-index variations experimental checked so far
//										/SH 20210705 V.1.11	introduce new vizual output style	
//										/SH 20210916 V.1.12	checking for the possibility of shift analysis and correction
//										/SH 20210916 V.1.13	introducing and checked optional multistackreg-registration
//										/SH 20210916 V.1.14	introduced optional median background subtraction (at least 10 images needed)
//										/SH 20210916 V.1.15	introduced documentation of user parameters
//										/SH 20210916 V.1.16	Proper annotation of relevant parts & introduced different default Autothresholds to choose from
//										/SH 20210916 V.1.17	Reworked preprocessing for Background for weaker samples before background marker is available
//										/SH 20211116 V.1.18	Introduced additional analysis using Mazza as a cell outline marker
//										/SH 20211116 V.1.19	Reworked first parameters for analysis of LSM900 Data;
//										/SH 20210929 V.1.20 Introducing readout of certain Metadata (Ex./Em./Int.) / PD and Non-PD-Count / Minimum PD / Non-PD-Check / Saving Cut-out ROI as original (fused later in the previous version)
//										/SH 20211118 V.1.21 Introduced size parameters for relevant filters median before PD, minimum size of PD size;  Reworking the placement of the BAckground ROIs not as center of mass of e.g. Mazza channel ROIs, but rather the EDM-Ultimate points as a improvement placement procedure
//										/SH 20211118 V.1.22 eliminated compatibility problems with mac; speeded up batch processing again; reworked the output style
//										/SH 20211130 V.1.23 Reworked MAC compatibility Bugs / Introduced compatibility with spinning disc files of 2 channels again

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

//Functions///////////////////////////////////////////////////////////////////////////////////

//-//

//Macro-Script///////////////////////////////////////////////////////////////////////////////

//Clean everything which is still open by chance
while (nImages>0) 
{ 
	selectImage(nImages); 
	close(); 
}
run("Clear Results");
roiManager("reset");
close("Log");
	
//Prepare for folder batch processing
list = getFileList(origDir); 
FSeperator = File.separator;
print(FSeperator);

//Grab time for timespamping the results
getDateAndTime(year, month, dayOfWeek, dayOfMonth, hour, minute, second, msec);
month = month+1;
starttime=getTime();

//Initialize VAriable for results table for later use
m=0;

//new V1.1 (sets a customized table with empty values and fills it later) //Multiple parallel Analysis introduced in V1.4
PlaceHolder = newArray();
Table.create("Results"); //new V1.1 use name "Results" to set it active
Table.setColumn("ImageName", PlaceHolder);			
Table.setColumn("DoubleSquarePD", PlaceHolder);
Table.setColumn("LowerThres", PlaceHolder);
Table.setColumn("UpperThres", PlaceHolder);
Table.setColumn("#PDs", PlaceHolder);
Table.setColumn("#nonPDs", PlaceHolder);
Table.setColumn("WARNINGS", PlaceHolder);
IJ.renameResults("ResultsTableOfAnalysis"); //new V1.1 use different name to set it inactive

// Create results directory
ResFolder = origDir+FSeperator+"Results_"+year+"_"+month+"_"+dayOfMonth+"__"+hour+"_"+minute+"_"+second+FSeperator;
File.makeDirectory(ResFolder);


// Create median background and subtract it, if choosen by the user

//Enter batchmode
if (BatchSpeed == 1)
{
	//setBatchMode("exit and display");
	setBatchMode(true);
}
		
if(MedianBackground == true)
{
	for (j = 0; j < list.length; j++)
	{
		Format = InputFormat;
		Extension = substring(list[j],lengthOf(list[j])-4,lengthOf(list[j]));
	
		//Check for format --> fail: Skip --> success: do processing
		if(Extension == Format)
		{
			//Create list and open files
			open(origDir+"\\"+list[j]);
		}	
	}
	
	//Create background image by Median-Intensity-Projection of all anilin channels of the images in folder
	run("Concatenate...", "all_open open");
	run("Z Project...", "projection=Median");
	selectWindow("Untitled");
	close();
	selectWindow("MED_Untitled");
	run("Split Channels");
	selectWindow("C1-MED_Untitled");
	close();
	selectWindow("C2-MED_Untitled");
	rename("Anilin-Common-Background");
	setMinAndMax(0, 65535);
	run("16-bit");
}

 
//Starting main-loop for 
for (j = 0; j < list.length; j++)
{
	Format = InputFormat;
	Extension = substring(list[j],lengthOf(list[j])-4,lengthOf(list[j]));

	//Check for format --> fail: Skip --> success: do processing
	if(Extension == Format)
	{
		//Create list and open files
		run("Bio-Formats", "open=["+origDir+FSeperator+list[j]+"] autoscale color_mode=Default rois_import=[ROI manager] view=Hyperstack stack_order=XYCZT");
		origName = replace(list[j], InputFormat,"");
		
		//Initialize / reset Arrays after every file
		AllX = newArray();
		AllY = newArray();
		SumPDIntensity = newArray();
		SumPDSize = newArray();
		SumPDSquareIntensity = newArray();
		SumBackIntensity = newArray();
		SumNoPDIntensity = newArray();
		SumPointDetecBackIntensity = newArray();
		SumPointDetecPDIntensity = newArray();
		SumSquareNonPDIntensity = newArray();

		//Test region for the metadata readout from V1.20
		if(MetaRead == true)
		{
			run("Show Info...");
			infoString=getMetadata("Info");
			chanPos=indexOf(infoString,"Information|Image|Channel|DetectionWavelength|Ranges #1");
			DetectionRange1=substring(infoString,chanPos+58,chanPos+70);
			chanPos=indexOf(infoString,"Information|Image|Channel|Wavelength #1");
			Excitation1=substring(infoString,chanPos+41,chanPos+45);
			chanPos=indexOf(infoString,"Information|Instrument|LightSource|Power #1");
			Intensity1=substring(infoString,chanPos+45,chanPos+48);
			print("Channel1 Detection = "+DetectionRange1+" nm / Excitation at "+Excitation1+" nm / Intensity set "+Intensity1);
			chanPos=indexOf(infoString,"Information|Image|Channel|DetectionWavelength|Ranges #2");
			DetectionRange2=substring(infoString,chanPos+58,chanPos+70);
			chanPos=indexOf(infoString,"Information|Image|Channel|Wavelength #2");
			Excitation2=substring(infoString,chanPos+41,chanPos+45);
			chanPos=indexOf(infoString,"Information|Instrument|LightSource|Power #2");
			Intensity2=substring(infoString,chanPos+45,chanPos+48);
			print("Channel2 Detection = "+DetectionRange2+" nm / Excitation at "+Excitation2+" nm / Intensity set "+Intensity2);
			selectWindow("Info for "+list[j]);
			print("Info for "+list[j]);
			run("Close"); //important here not to use close(); otherwise it wont close the InfoWindow, but the active image
		}

		//Register channels by Multistackreg, if choosen by the user
		if (ChannelCorrection == true)
		{
			selectWindow(list[j]);
			rename("Temp");
			run("Split Channels");
			run("MultiStackReg", "stack_1=[C2-Temp] action_1=[Use as Reference] file_1=[] stack_2=[C1-Temp] action_2=[Align to First Stack] file_2=[] transformation=[Rigid Body]");
			run("Merge Channels...", "c2=[C1-Temp] c3=[C2-Temp] create");
			rename(list[j]);
		}
		
		//Subtract gegerated median background, if choosen by the user
		if (MedianBackground == true)
		{
			selectWindow(list[j]);
			run("Split Channels");
			imageCalculator("Subtract create", "C2-"+list[j],"Anilin-Common-Background");
			rename("Subtracted-Anilin");
			selectWindow("C2-"+list[j]);
			close();
			run("Merge Channels...", "c2=[C1-"+list[j]+"] c3=[Subtracted-Anilin] create");
			rename(list[j]);
		}

		//Descale
		selectWindow(list[j]);
		getPixelSize(unit, pixelWidth, pixelHeight);
		run("Set Scale...", "distance=0 known=0 pixel=1 unit=pixel");
		ImageName=getTitle();
		setTool("rectangle");
		Stack.setChannel(1);
		run("Green");
		run("Enhance Contrast", "saturated=0.05");
		Stack.setChannel(2);
		run("Magenta");
		run("Enhance Contrast", "saturated=0.35");

		//Show all hidden images for cropping
		if (BatchSpeed == 1)
		{
			setBatchMode("exit and display");
			//setBatchMode(true);
		}
		
		//Give user the option to focus on ROI
		Stack.setDisplayMode("composite");
		Stack.setActiveChannels("110");
		waitForUser("Mark a region with as clear as possible PD- and NoPD area/n and regions of similar overall intensity for the protein of interest!");
		Stack.setDisplayMode("grayscale");
		Stack.setChannel(2);
		setMinAndMax(0, 65535);
		run("Duplicate...", "duplicate");
		
		rename("Cropped");
		selectWindow(ImageName);
		close();
		rename("Original2Channel");
		run("Duplicate...", "duplicate");
		rename("Original");
		run("Split Channels");
		selectWindow("C1-Original");
		rename("GFP-Original");
		setMinAndMax(0, 65535);
		selectWindow("C2-Original");
		rename("Anilin-Original");
		setMinAndMax(0, 65535);

		if (ChannelCount == "2channel")
		{
			selectWindow("Anilin-Original");
			run("Duplicate...", "duplicate");
			rename("Periphery-Original");
			setMinAndMax(0, 65535);
		}
		else if (ChannelCount == "3channel")
		{
			selectWindow("C3-Original");
			rename("Periphery-Original");
			setMinAndMax(0, 65535);
		}
		
		//Do PD outline
		selectWindow("Anilin-Original");
		run("Duplicate...", "duplicate");
		rename("Anilin-PD");
		selectWindow("Anilin-PD");
		if (PreMedian == 1)
		{
			run("Median...", "radius="+PDMedian+" slice");
		}
		resetMinAndMax();

		//Show all hidden images for thresholding
		if (BatchSpeed == 1)
		{
			setBatchMode("exit and display");
			//setBatchMode(true);
		}

		//Suggesting an outomatic threshold by default (here "Yen") but waiting for approval of the user
		run("Threshold...");
		setAutoThreshold(AutoThres+" dark");
		setAutoThreshold("Default dark");
		setAutoThreshold(AutoThres+" dark");
		
		waitForUser("Select a threshold for PD´s and press OK");

		//Enter batchmode again
		if (BatchSpeed == 1)
		{
			//setBatchMode("exit and display");
			setBatchMode(true);
		}
		
		getThreshold(lowerPD, upperPD);
		run("Convert to Mask");
		rename("Anilin-PD-Outline");

		//Finally identifying the PD´s
		run("Set Measurements...", "area mean standard modal min centroid center perimeter bounding fit shape feret's integrated median skewness kurtosis area_fraction redirect=GFP-Original decimal=3");
		run("Analyze Particles...", "size=5-Infinity pixel show=Masks display clear add");

		//Store the center points and sizes of the identified PDs
		for (i = 0; i < nResults(); i++) 
		{
			TempX = getResult("X", i);
			TempY = getResult("Y", i);
			TempPDSize = getResult("Area", i);
			SumPDSize = Array.concat(SumPDSize,TempPDSize);
			AllX = Array.concat(AllX,TempX);
			AllY = Array.concat(AllY,TempY);
		}
		getDimensions(width, height, channels, slices, frames);
		newImage("SquaresGreen", "black", width, height, 1);
		Array.getStatistics(SumPDSize, min, max, mean, stdDev);
		print(mean);
		PDSizeMean = mean;
		PDpixelSize = sqrt(mean);
		print(PDpixelSize);
		//introduced PD-size to improve size of the PD-Measurement slightly by increasing size to fit PD´s better on visual check
		PDSizeMean = PDpixelSize*PDSizeOffset;

		//Measure the fluorescent intensities at the PD´s in the original Fluorescent image (first channel), store results and draw rectangle indicators in green
		for (i = 0; i < AllX.length; i++) 
		{
			selectWindow("GFP-Original");
			makeRectangle(AllX[i]-(PDSizeMean/2), AllY[i]-(PDSizeMean/2), PDSizeMean, PDSizeMean);
			run("Measure");
			TempPDSquareIntensities = getResult("Mean", nResults-1);
			SumPDSquareIntensity = Array.concat(SumPDSquareIntensity,TempPDSquareIntensities);
			selectWindow("SquaresGreen");
			setColor("green");
			drawRect(AllX[i]-(PDSizeMean/2), AllY[i]-(PDSizeMean/2), PDSizeMean, PDSizeMean);
			IJ.deleteRows( nResults-1, nResults-1 ); 
		}

		//Preprocessing to generate background regions
		selectWindow("Periphery-Original");
		resetMinAndMax();
		run("Duplicate...", "duplicate");
		rename("Periphery-NonPD");
		run("8-bit");
		//run("Subtract Background...", "rolling=20"); //new
		run("Median...", "radius=3");
		run("Auto Local Threshold", "method=Median radius="+LocalThreshold+" parameter_1=0 parameter_2=0 white");
		run("Set Measurements...", "area mean standard modal min centroid center perimeter bounding fit shape feret's integrated median skewness kurtosis area_fraction redirect=None decimal=3");
		run("Analyze Particles...", "size=500-Infinity pixel show=Masks display clear add");
		run("Median...", "radius=3");
		run("Despeckle");
		run("Undo");
		run("Despeckle");
		run("Median...", "radius="+BGMedian); //bigger with higher sampling rate and smaller with lower sampling; introduced user variable later
		run("Options...", "iterations="+MaskSmoothing+" count=1 black do=Dilate");
		run("Options...", "iterations="+MaskSmoothing+" count=1 black do=Erode");
		run("Duplicate...", "duplicate");
		rename("BackgroundMask");
		run("Convert to Mask");
		run("Open");
		run("Skeletonize");
		run("Options...", "iterations="+MaskDilation+" count=1 black do=Dilate"); //bigger with higher sampling rate and smaller with lower sampling; introduced user variable later
		imageCalculator("Subtract create", "BackgroundMask","Anilin-PD-Outline");
		selectWindow("Result of BackgroundMask");
		//run("Salt and Pepper"); //intro before V1.18 to cut down 
		rename("Outline Mask");
		run("Duplicate...", " ");
		rename("BackgroundDots");
		waitForUser("???");
		run("Ultimate Points");
		setOption("BlackBackground", true);
		run("Convert to Mask");
		run("Analyze Particles...", "  show=Masks display clear add");

		
		//enter hidden batch mode to speed up
		//setBatchMode(true);

		//Measure the fluorescent intensities at the backgrounds in the original Fluorescent image (first channel), store results and draw rectangle indicators in red
		AllX = newArray();
		AllY = newArray();
		for (i = 0; i < nResults(); i++) 
		{
			TempX = getResult("X", i);
			TempY = getResult("Y", i);
			TempNoPDIntensity = getResult("Mean", i);
			SumAreaNonPDIntensity = Array.concat(SumAreaNonPDIntensity,TempNoPDIntensity);
			AllX = Array.concat(AllX,TempX);
			AllY = Array.concat(AllY,TempY);
		}
		run("Clear Results");
		newImage("SquaresRed", "black", width, height, 1);
		for (i = 0; i < AllX.length; i++) 
		{
			selectWindow("GFP-Original");
			makeRectangle(AllX[i]-(PDSizeMean/2), AllY[i]-(PDSizeMean/2), PDSizeMean, PDSizeMean);
			run("Measure");
			TempBackIntensities = getResult("Mean", nResults-1);
			SumSquareNonPDIntensity = Array.concat(SumSquareNonPDIntensity,TempBackIntensities);
			selectWindow("SquaresRed");
			setColor("red");
			drawRect(AllX[i]-(PDSizeMean/2), AllY[i]-(PDSizeMean/2), PDSizeMean, PDSizeMean);
			IJ.deleteRows( nResults-1, nResults-1 ); 
		}
		
	
		//Prepare output of the PD- and Non-PD-arrays and generating simple statistics (avgs) of the values / logging in txt file
		SumSquareNonPDIntensity = Array.deleteIndex(SumSquareNonPDIntensity, 0);
		print("SquareNonPDs");
		Array.print(SumSquareNonPDIntensity);
		print("SquarePDs");
		Array.print(SumPDSquareIntensity);
		Array.getStatistics(SumSquareNonPDIntensity, SquareNonPDmin, SquareNonPDmax, SquareNonPDmean, SquareNonPDstdDev);
		Array.getStatistics(SumPDSquareIntensity, SquarePDmin, SquarePDmax, SquarePDmean, SquarePDstdDev);
		print("SquareBackground Max: "+SquareNonPDmax+" Min: "+SquareNonPDmin+" Mean: "+SquareNonPDmean+" stdDev: "+SquareNonPDstdDev);
		print("SquarePD Max: "+SquarePDmax+" Min: "+SquarePDmin+" Mean: "+SquarePDmean+" stdDev: "+SquarePDstdDev);

		//Calculating the ratio between Square-PD-Means and Non-Square-PD-Means as PD-Index
		PDDoubleSquareIndex = SquarePDmean/SquareNonPDmean;
		print("PDindex with both squares = "+PDDoubleSquareIndex);

		//Storing results in the table
		selectWindow("ResultsTableOfAnalysis");
		IJ.renameResults("Results"); //activate table
		setResult("ImageName", m, origName);
		setResult("DoubleSquarePD", m, PDDoubleSquareIndex);
		setResult("LowerThres", m, lowerPD);
		setResult("UpperThres", m, upperPD);
		setResult("#PDs", m, SumPDSquareIntensity.length);
		setResult("#nonPDs", m, SumSquareNonPDIntensity.length);
		if ( SumPDSquareIntensity.length < 3 || SumSquareNonPDIntensity.length < 3)
		{
			setResult("WARNINGS", m, "Low#!!!");
			print("!!!WARNING, LOW PD Count!!!");
		}
		else 
		{
			setResult("WARNINGS", m, "");
		}
		updateResults();
		m++; //new V1.1 counter to find right position in customized results table even when switching to another file in batch processing
		IJ.renameResults("ResultsTableOfAnalysis"); //deactivate table
	
		//Preparing contrasts for visual output
		selectWindow("GFP-Original");
		resetMinAndMax();
		//run("Enhance Contrast", "saturated=0.05");
		run("8-bit");
		selectWindow("Anilin-Original");
		resetMinAndMax();
		run("Enhance Contrast", "saturated=0.05");
		run("8-bit");
		selectWindow("Periphery-Original");
		resetMinAndMax();
		run("Enhance Contrast", "saturated=0.05");
		run("8-bit");
		
		//Combining output image
		run("Merge Channels...", "c1=SquaresRed c2=SquaresGreen c4=Anilin-Original create keep ignore");
		run("Flatten");
		rename("AnilinSquares");

		
		run("Merge Channels...", "c1=SquaresRed c2=SquaresGreen c4=Periphery-Original create keep ignore");
		run("Flatten");
		rename("PeripherySquares");

		
		run("Merge Channels...", "c1=SquaresRed c2=SquaresGreen c4=GFP-Original create keep ignore");
		run("Flatten");
		rename("GFPSquares");


		run("Merge Channels...", "c1=[Outline Mask] c2=Anilin-PD-Outline create keep");
		run("Flatten");
		rename("MasksOverlay");
		
		run("Combine...", "stack1=AnilinSquares stack2=PeripherySquares combine");
		rename("FirstCombine");
		
		run("Combine...", "stack1=GFPSquares stack2=MasksOverlay combine");
		rename("SecondCombine");
		run("Combine...", "stack1=[FirstCombine] stack2=[SecondCombine]");
		rename("FinalOutput");


		selectWindow("GFP-Original");
		close();
		selectWindow("Mask of BackgroundDots");
		close();
		selectWindow("Outline Mask");
		close();
		selectWindow("Periphery-NonPD");
		close();
		selectWindow("SquaresRed");
		close();
		selectWindow("SquaresGreen");
		close();
		selectWindow("Anilin-Original");
		close();
		selectWindow("BackgroundDots");
		close();
		selectWindow("BackgroundMask");
		close();
		selectWindow("Mask of Anilin-PD-Outline");
		close();
		selectWindow("Mask of Periphery-NonPD");
		close();
		selectWindow("Anilin-PD-Outline");
		close();
		selectWindow("Periphery-Original");
		close();
		
		//Show all hidden images for saving
		if (BatchSpeed == 1)
		{
			setBatchMode("exit and display");
			//setBatchMode(true);
		}
		
		//Save everything that is needed
		selectWindow("FinalOutput");
		saveAs("Tiff", ResFolder+origName+"_Square_Quantification.tiff");
		selectWindow(origName+"_Square_Quantification.tiff");
		close();
		selectWindow("Original2Channel");
		saveAs("Tiff", ResFolder+origName+"_OriginalROICrop.tiff");
		close();
		selectWindow("Log");
		save(ResFolder+origName+".txt");
		close("Log");
		roiManager("reset");
		print("\\Clear");
	}
	else 
	{
		//return message of the skip for the user if the file in the main loop was not a *.tif image 
		print(list[j]+" is not an "+Format+" image and was skipped");
	}
//Closing the main loop / restarting for the next file
}

//Save the overall results table
selectWindow("ResultsTableOfAnalysis");
save(ResFolder+"TotalResult.txt");
close("TotalResult.txt");

//Close Background-image
if(MedianBackground == true)
{	
	
	selectWindow("Anilin-Common-Background");
	saveAs("Tiff", ResFolder+"CalculatedBackground.tiff");
	close();
}

//Create and save documentation of the choosen parameters
run("Clear Results");
roiManager("reset");
print("\\Clear");
print("Raw data folder:");
print(origDir);
print("__________________________________________________");
print("Files used:");
for (j = 0; j < list.length; j++)
{
	Format = InputFormat;
	Extension = substring(list[j],lengthOf(list[j])-4,lengthOf(list[j]));

	//Check for format --> fail: Skip --> success: do processing
	if(Extension == Format)
	{
		//Add to document
		print(list[j]);
	}
}

print("__________________________________________________");
print("Used parameters:");
print("Shift correction: "+ChannelCorrection);
print("Median Background Correction: "+MedianBackground);
print("Pre-PD definition Median used?: "+PreMedian);
print("Factor of Pre-PD Median?: "+PDMedian);
print("Added value to the variable size of a PD: "+PDSizeOffset);
print("Median factor before defining background areas : "+BGMedian);
print("LocalThreshold radius factor : "+LocalThreshold);
print("Smoothing factor for the background binaries: "+MaskSmoothing);
print("Median factor before defining background areas : "+MaskSmoothing);
print("Dilation factor for for background outline : "+MaskDilation);
print("Choosen default Autothreshold, if it was not modified manually: "+AutoThres);
print("__________________________________________________");
print("Results saved to:");
print(ResFolder);

//Calculate final time, in order to track performance and possibilities to speed up
endtime=getTime();
timeDifference=endtime-starttime;
seconds = timeDifference/1000;
minutes = floor(seconds/60);
seconds = seconds - minutes*60;
hours = floor(minutes/60);
minutes = minutes - hours*60;
print("\nIt took "+hours+" hours, "+minutes+" minutes and "+seconds+" seconds for calculation!");
	
selectWindow("Log");
save(ResFolder+"ParamenterLog.txt");
print("\\Clear");
close("Log");

//Finish
beep();
showMessage("Analysis Done!");