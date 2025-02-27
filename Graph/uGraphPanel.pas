unit uGraphPanel;

interface
uses SysUtils, Classes, Graphics, Controls, System.Types, System.Generics.Collections,
     Dialogs, WEBLib.StdCtrls, WEBLib.ExtCtrls, WEBLib.Forms, JS, Web,
     uWebScrollingChart, uWebGlobalData, ufYAxisMinMaxEdit,  uSidewinderTypes;

const SERIESCOLORS: array[0..10] of integer = ( clRed, clBlue, clGreen,clBlack,
                     clAqua, clGray,clPurple,clOlive, clLime,clSkyBlue, clYellow);
      EDIT_TYPE_DELETEPLOT = 0;
      EDIT_TYPE_SPECIES = 1;
      DEFAULT_Y_MAX = 10;
      DEFAULT_MAX_XPTS = 1000;
      DEFAULT_MIN_PTS = 50;
      DEFAULT_X_MAX = 10;  // typically 10 sec

type
TEditGraphEvent = procedure(position: integer; editType: integer) of object;

TGraphPanel = class (TWebPanel)
private
  chart: TWebScrollingChart;
  seriesStrList: TList<string>; // series label list, if '' then do not plot
  lbEditGraph: TWebListBox;
  yMaximum: double;
  yMinimum: double;
  yLabel: string;
  xLabel: string;
  autoUp: boolean;  // Auto scale y axis up
  autoDown: boolean;
  timeDelta: double;
  xMax: double;  // default is 10, time window of graph
  chartBackGroundColor: TColor;
  fEditGraphEvent: TEditGraphEvent;
  staticGraph: boolean; // true = static run
  function updateXMax(): boolean; // true if changed. Adjust xMax if total points > DEFAULT_MAX_XPTS or < DEFAULT_MIN_XPTS
  {procedure graphEditMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
  procedure editGraphListBoxClick(Sender: TObject); }

public
  userDeleteGraph: boolean; // true, user can delete graph (OnEditGraphEvent method required)
  userChangeVarSeries: boolean; // true, user can change var of series (OnEditGraphEvent method required)
  plotEditInProgress: boolean;

  constructor create(newParent: TWebPanel; graphPosition: integer; yMax: double);
  procedure initializePlot(newVarStrList: TList<string>; newYMax: double; newYMin: double;
  newAutoUp: boolean; newAutoDown: boolean; newDelta: double; newBkgrndColor: TColor);
  procedure setAutoScaleUp(autoScale: boolean); // true: autoscale
  procedure setAutoScaleDown(autoScale: boolean); // true: autoscale
  procedure addChartSerie(varStr: string; maxYVal: double); // need max Y if autoScale off
  procedure setTimer(newTimer: TWebTimer); // Not sure this is necessary
  procedure setPanelColor( val: TColor ); // background color for TGraphPanel
  procedure setPanelHeight( newHeight: integer ); // Set height for panel that contains chart
  procedure setPanelTop( val: integer ); // set Top  relative to top of parent panel
  procedure setSeriesColors();
  procedure setSerieColor(index: integer; newColor: TColor);
  procedure deleteChartSerie(index: integer);
  procedure deleteChartSeries();
  procedure deleteChart(); // delete TWebScrollingChart
  procedure createChart();
  procedure setupChart(); // Setup chart based on existing values from and instance of TGraphPanel
  procedure restartChart(newInterval: double); // Needed ??
  procedure setChartDelta(newDelta: double);
  procedure setChartWidth(newWidth: integer);
  procedure setChartTimeInterval(newInterval: double);
  function  getChartTimeInterval(): double;
  procedure setXAxisLabel(newLabel: string);
  function  getXAxisLabel(): string;
  procedure setYAxisLabel(newLabel: string);
  function  getYAxisLabel(): string;
  procedure setYMax(newYMax: double);
  function  getYMax(): double;
  function  getYMin(): double;
  procedure setXMax(newXMax: double);
  function  getXMax(): double;
  procedure updateYMinMax(yMin: double; yMax:double);
  procedure toggleLegendVisibility();
  function  isLegendVisible(): boolean;
  procedure toggleAutoScaleYaxis();
  function  isAutoScale(): boolean;
  procedure setStaticGraph(val: boolean);
  procedure adjustPanelHeight(newHeight: integer); // adjust height and top, uses self.tag as well
  procedure getVals( newTime: Double; newVals: TVarNameValList);// Get new values (species amt) from simulation run
  procedure setStaticSimResults( newResults: TList<TTimeVarNameValList> ); // get sim results to plot
  procedure notifyGraphEvent(plot_id: integer; eventType: integer);
  procedure chartUpdateYMinMax(yMax: double; yMin: double); // Listener
  property OnEditGraphEvent: TEditGraphEvent read fEditGraphEvent write fEditGraphEvent;
end;

implementation

constructor TGraphPanel.create(newParent: TWebPanel; graphPosition: integer; yMax: double);
begin
  inherited create(newParent);
  self.plotEditInProgress := false;
  self.staticGraph := false;
  self.SetParent(newParent);
  if graphPosition > -1 then self.tag := graphPosition
  else self.tag := 0;
  self.Width := newParent.Width;
  self.Anchors := [akLeft,akRight,akTop];
  self.Height := round(newParent.height/2); // Default
  self.Left := 10; // gap between panel to left and plot
  self.Top := 4 + self.Height*(graphPosition -1);
  self.Color := clwhite; // default
  self.chartBackGroundColor := -1;
  self.userDeleteGraph := false;
  self.userChangeVarSeries := false;
  self.yLabel := 'Conc';  // Default
  self.xLabel := 'unit time'; // Default
  self.xMax := DEFAULT_X_MAX;
  self.yMinimum := 0;
  if yMax > 0 then self.yMaximum := yMax
  else self.yMaximum := DEFAULT_Y_MAX;
  self.createChart();
end;

 procedure TGraphPanel.createChart();
 begin
   try
     self.chart := TWebScrollingChart.Create(self);
     self.chart.Height := self.Height;
  //   self.chart.OnMouseClickEvent := self.graphEditMouseDown;
     self.chart.Parent := self;
     self.chart.OnYMinMaxChangeEvent := self.chartUpdateYMinMax;
     self.chart.AxisStrokeWidth := 1;
   //  console.log('createChart: yMax: ', self.yMaximum);
     if self.yMaximum > 0 then self.chart.YAxisMax := self.yMaximum
     else self.chart.YAxisMax := DEFAULT_Y_MAX;
     if self.yMinimum < 0 then self.chart.YAxisMin := 0
     else self.chart.YAxisMin := self.yMinimum;
   except
    on E: Exception do
      notifyUser(E.message);
  end;
 end;

procedure TGraphPanel.initializePlot( newVarStrList: TList<string>; newYMax: double;
          newYMin: double; newAutoUp: boolean; newAutoDown: boolean; newDelta: double;
          newBkgrndColor: TColor);
var i: integer;
begin
  self.seriesStrList := newVarStrList;
  if newYMax > 0 then self.yMaximum := newYmax; // Assume max value > zero
  self.yMinimum := newYMin;
  self.autoUp := newAutoUp;
  self.autoDown := newAutoDown;
  self.timeDelta := newDelta;

  self.chartBackGroundColor := newBkgrndColor;
  //self.Color := clBlack;
  self.setupChart();
end;
procedure TGraphPanel.setupChart;
var i: integer;
begin
 // self.yLabel := 'Conc';  // Default
 // self.xLabel := 'unit time'; // Default
  self.chart.autoScaleUp := self.autoUp;
  self.chart.autoScaleDown := self.autoDown;
  self.chart.YAxisMax := self.yMaximum;
  self.chart.YAxisMin := self.yMinimum;
  self.chart.SetChartTitle(''); // Do not use, if so then need to adjust plot grid height
  self.chart.setYAxisCaption(''); // Add to bottom, xaxis label. Cannot rotate label in HTML ?
  self.chart.SetXAxisCaption( self.yLabel + ' vs. '+ self.xLabel );
  self.setChartDelta(self.timeDelta);
  if not self.staticGraph then self.updateXMax(); // Not needed for 'static' sim run.
  self.setChartTimeInterval(self.timeDelta); // ?? is this necessary?
  //self.chart.SetXAxisMax(TConst.DEFAULT_X_POINTS_DISPLAYED *self.timeDelta); // deltaX same as interval
  self.chart.SetXAxisMax(self.xMax); // deltaX same as interval
  if self.chartBackGroundColor < 1 then self.chart.BackgroundColor := clNavy
  else self.chart.BackgroundColor := self.chartBackGroundColor;
  self.chart.LegendBackgroundColor := clWebFloralWhite; //clSilver;
  self.chart.LegendPosX := 0;
  self.chart.LegendPosY := 15;

  for i := 0 to self.seriesStrList.count -1 do
    begin
    if self.seriesStrList[i] <> '' then
      self.chart.AddSerie(self.seriesStrList[i]);
    end;
  self.setSeriesColors;

end;

function TGraphPanel.updateXMax(): boolean;
// Let plot point density guide value of xMax
begin
  Result := false; // return false if self.xMax does not change.
  if DEFAULT_X_MAX / self.timeDelta > DEFAULT_MAX_XPTS then
    begin
    self.xMax := DEFAULT_MAX_XPTS * self.timeDelta;
    Result := true;
    end
  else
    begin
    if DEFAULT_X_MAX / self.timeDelta < DEFAULT_MIN_PTS then
         begin
         self.xMax := DEFAULT_MIN_PTS * self.timeDelta;
         Result := true;
         end
    else if self.xMax <> DEFAULT_X_MAX then
           begin
           self.xMax := DEFAULT_X_MAX;
           Result := true;
           end;
    end;
   if assigned(self.chart) then self.chart.SetXAxisMax(self.xMax);    // ok ????

end;


procedure TGraphPanel.chartUpdateYMinMax(yMax: double; yMin: double);
// Listener: graphPanel notified that chart y min/max has changed
begin
//console.log('TGraphPanel.chartUpdateYMinMax', yMax);
  self.yMaximum := yMax;
  self.yMinimum := yMin;
end;
procedure TGraphPanel.setYMax(newYMax: double);
begin
  if self.chart.YAxisMin < newYMax then
    self.chart.YAxisMax := newYMax;
end;

function  TGraphPanel.getYMax(): double;
begin
  Result := self.yMaximum;
end;

function  TGraphPanel.getYMin(): double;
begin
  Result := self.yMinimum;
end;

procedure TGraphPanel.setXMax(newXMax: double);
// Different then updateXMax, not concerned about plot point density, just set xMax
begin
  if (newXMax >0) and (self.xMax <> newXMax) then
    begin
      self.xMax := newXMax;
      if assigned(self.chart) then
        self.chart.SetXAxisMax(newXMax);
    end;
end;

function TGraphPanel.getXMax(): double;
begin
  Result := self.xMax;
end;

procedure TGraphPanel.setPanelHeight( newHeight: integer ); // Set height for panel that contains chart
begin
  if newHeight >0 then
    begin
    self.Height := newHeight;
    self.chart.Height := self.Height;
    end;
  self.Invalidate;
end;

procedure TGraphPanel.adjustPanelHeight( newHeight: integer );// adjusts based on tag value
begin
  self.Height:= newHeight;
  self.Top:= 5 + newHeight*(self.tag -1);
  self.chart.Height := newHeight;
  self.invalidate;

end;

procedure TGraphPanel.setChartWidth(newWidth: integer);
begin
  if newWidth <= self.width then self.chart.width := newWidth;
end;

procedure TGraphPanel.setPanelTop( val: integer ); // set Top  relative to top of parent panel
begin
  if val > -1 then self.Top := val
  else self.Top := 4;
end;

procedure TGraphPanel.setPanelColor( val: TColor); // background color for TGraphPanel
begin
  if val >0 then self.color := val;
  self.Invalidate;
end;

procedure TGraphPanel.setSeriesColors();
var i: integer;
begin
  for i := 0 to length(self.chart.series)-1 do
    begin
    self.setSerieColor(i,0);
    end;
end;

procedure TGraphPanel.setSerieColor(index: Integer; newColor: TColor);
var j: integer;
begin
  if index < length(self.chart.series) then
    begin
    if newColor > 1 then self.chart.series[index].color := newColor
    else
      begin
      for j := 0 to self.seriesStrList.Count -1 do  // Want all charts to use same color for var
        begin
         if self.chart.series[index].name = self.seriesStrList[j] then
           begin
           if index < length(SERIESCOLORS)then self.chart.series[index].color := SERIESCOLORS[j]
           else self.chart.series[index].color := SERIESCOLORS[j mod length(SERIESCOLORS)];
           end;
        end;
      end;
    end;
end;

procedure TGraphPanel.setTimer(newTimer: TWebTimer);  // should not be necessary
begin
  self.chart.ExternalTimer := newTimer;
end;


procedure TGraphPanel.setChartTimeInterval(newInterval: double); // seconds, necessary ??
begin
  self.chart.SetInterval(round(newInterval*1000)); // convert to msec (integer)
end;

function  TGraphPanel.getChartTimeInterval(): double;
begin
  Result := self.chart.GetInterval / 1000;
end;

procedure TGraphPanel.setStaticGraph(val: boolean);
begin
  self.staticGraph := val;
  if val then
    begin
    self.chart.SetXAxisMax(self.xMax);
    end;
end;


procedure TGraphPanel.getVals(newTime: Double; newVals: TVarNameValList); // callback
var {i,} j: integer;
begin
  for j := 0 to length(self.chart.series) -1 do
    begin
    if j < newVals.getNumPairs then
      self.chart.updateSerie(j, newTime, newVals.getNameValById(self.chart.series[j].name).Val );
    end;
  self.chart.plot;

end;

procedure TGraphPanel.setStaticSimResults( newResults: TList<TTimeVarNameValList> );
var i, j: integer;
begin
//console.log('TGraphPanel.setStaticSimResults: yMax before: ', self.yMaximum);
  self.yMaximum := self.chart.YAxisMax;
  self.yMinimum := self.chart.YAxisMin;
 // console.log('yMax after: ', self.yMaximum);
  for i := 0 to newResults.count -1 do
    begin
    for j := 0 to length(self.chart.series) -1 do
      begin
      if j < newResults[i].varNV_List.getNumPairs then
        self.chart.updateSerie(j, newResults[i].time,
                   newResults[i].varNV_List.getNameValById(self.chart.series[j].name).Val );
      end;

    end;
   self.chart.plot;
end;

procedure TGraphPanel.setChartDelta(newDelta: double); // default is 0.1 (tenth of sec )
begin
if newDelta >0 then
  begin
  self.timeDelta := newDelta;
  if self.chart <> nil then
    begin
    self.chart.DeltaX := newDelta;  // integrator stepsize
    if not self.staticGraph then
      if self.updateXMax then
        begin
        self.setChartTimeInterval(self.chart.DeltaX); // needed ??
        self.chart.SetXAxisMax(self.xMax); // deltaX same as interval
        end;
    end;
  end
else console.log('TGraphPanel.setChartDelta value is not greater than zero');
end;

procedure TGraphPanel.addChartSerie(varStr: string; maxYVal: double);
begin
  if maxYVal > self.chart.YAxisMax then self.chart.YAxisMax := maxYVal;

  self.chart.AddSerieByName(varStr);
end;

procedure TGraphPanel.deleteChartSerie(index: integer);
begin
  self.deleteChartSerie(index);
end;

procedure TGraphPanel.deleteChartSeries();
begin
  self.chart.DeleteSeries;
end;

procedure TGraphPanel.deleteChart();
begin
  if self.chart <> nil then
    begin
    self.deleteChartSeries;
    self.chart.Destroy;
    end;

end;

procedure TGraphPanel.restartChart(newInterval: double); // Needed ? Issue resetting xAis labels
begin
  self.setChartDelta(newInterval); // ? chat delta versus chart time interval?
  self.setChartTimeInterval(newInterval);
  if not self.staticGraph then
    begin
    if self.updateXMax then
      self.chart.SetXAxisMax(self.xMax)
    else self.chart.SetXAxisMax(TConst.DEFAULT_X_POINTS_DISPLAYED * newInterval);
    end;
  self.chart.Restart;
end;

procedure TGraphPanel.setAutoScaleUp(autoScale: boolean);
begin
  self.chart.autoScaleUp := autoScale;
end;

procedure TGraphPanel.setAutoScaleDown(autoScale: boolean);
begin
  self.chart.autoScaleDown := autoScale;
end;

procedure TGraphPanel.toggleLegendVisibility;
begin
  if self.chart.getLegendVisible then
     self.chart.SetLegendVisible(false)
  else self.chart.SetLegendVisible(true);
end;

function TGraphPanel.isLegendVisible(): boolean;
begin
  Result := self.chart.GetLegendVisible;
end;

procedure TGraphPanel.toggleAutoScaleYaxis;
begin
  if self.chart.autoScaleUp then
    begin
    self.autoUp := false;
    self.chart.autoScaleUp := false;
    self.autoDown := false;
    self.chart.autoScaleDown := false;
    end
  else
    begin
    self.autoUp := true;
    self.chart.autoScaleUp := true;
    self.autoDown := true;
    self.chart.autoScaleDown := true;
    end;
end;

function TGraphPanel.isAutoScale(): boolean;
begin
  Result := self.autoUp;
end;

procedure TGraphPanel.updateYMinMax(yMin: double; yMax: double);
begin
 // self.chart.userUpdateMinMax;
  if yMin <0 then yMin := 0; // No negative amts

  if (yMin <> self.yMinimum) or (yMax <> self.yMaximum ) then
    if yMax > yMin then
      self.chart.userUpdateMinMax(yMin, yMax);
{  if self.chart.autoScaleUp then  // Turn off autoscale.
    begin
    self.chart.autoScaleUp := false;
    self.chart.autoScaleDown := false;
    end;    }
end;

procedure TGraphPanel.setXAxisLabel(newLabel: string);
begin
  self.xLabel := newLabel;
end;

function TGraphPanel.getXAxisLabel(): string;
begin
  Result := self.xLabel;
end;

procedure TGraphPanel.setYAxisLabel(newLabel: string);
begin
  self.yLabel := newLabel;
end;

function TGraphPanel.getYAxisLabel(): string;
begin
  Result := self.yLabel;
end;

procedure TGraphPanel.notifyGraphEvent(plot_id: integer; eventType: integer);
begin
   if Assigned(fEditGraphEvent) then
    fEditGraphEvent(plot_id, eventType);
end;

end.
